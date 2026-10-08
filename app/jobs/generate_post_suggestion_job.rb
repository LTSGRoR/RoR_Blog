class GeneratePostSuggestionJob < ApplicationJob
  queue_as :default

  # Terminal user-facing message when generation fails. The frontend polls
  # `ready: bot_response.present?`, so leaving it blank would poll forever.
  GENERATION_FAILED_MESSAGE = "Sorry, the assistant is temporarily unavailable. Please try again shortly."

  MAX_RAG_HITS = ENV.fetch("AI_CHAT_RAG_HITS", "5").to_i
  MAX_HISTORY_RAG_HITS = ENV.fetch("AI_CHAT_HISTORY_RAG_HITS", "3").to_i
  MAX_HISTORY_RAG_POOL = ENV.fetch("AI_CHAT_HISTORY_RAG_POOL", "12").to_i
  ANCHOR_CONTEXT_TRUNCATE_CHARS = ENV.fetch("AI_CHAT_ANCHOR_CONTEXT_CHARS", "1000").to_i
  RELATED_CONTEXT_TRUNCATE_CHARS = ENV.fetch("AI_CHAT_RELATED_CONTEXT_CHARS", "800").to_i
  HISTORY_CONTEXT_TRUNCATE_CHARS = ENV.fetch("AI_CHAT_HISTORY_CONTEXT_CHARS", "900").to_i
  MIN_POST_SIMILARITY = ENV.fetch("AI_CHAT_MIN_POST_SIMILARITY", "0.35").to_f

  def perform(chat_history_id, locale = nil)
    requested_locale = locale.presence || ChatHistory.find_by(id: chat_history_id)&.user&.locale
    selected_locale = I18n.available_locales.map(&:to_s).include?(requested_locale.to_s) ? requested_locale : I18n.default_locale
    I18n.with_locale(selected_locale) { generate_response(chat_history_id) }
  end

  private

  def generate_response(chat_history_id)
    chat = ChatHistory.find_by(id: chat_history_id)
    return unless chat
    return if chat.bot_response.present?
    if chat.created_at < ChatHistory::REQUEST_TTL.ago
      mark_chat_failed(chat, reason: "Request expired before processing")
      return
    end

    service = AiGeneration::Service.new

    # Retrieval-Augmented Generation using pgvector embeddings (if available)
    recent_history = chat.chat_session.chat_histories.visible.where("id < ?", chat.id)
                         .where.not(bot_response: nil).order(id: :desc).limit(6).to_a.reverse
    recent_history.reject! { |history| policy_rejected_history?(history) }
    prompt_context = recent_history.map { |history| build_history_context(history) }
    small_talk = small_talk?(chat.user_message)
    policy = AiGeneration::AssistantPolicy.new(service)
    category = small_talk ? "small_talk" : policy.request_category(
      message: chat.user_message, post_id: chat.post_id,
      conversation: recent_history.map { |history| history.user_message.to_s.truncate(HISTORY_CONTEXT_TRUNCATE_CHARS) }
    )
    unless %w[blog_content small_talk].include?(category)
      persist_policy_response(chat, reason: category)
      return
    end
    small_talk ||= category == "small_talk"
    post_context = []
    candidate_post_ids = []
    candidate_chat_history_ids = []
    begin
      # Always anchor on the current post first when available.
      if chat.post.present? && !small_talk
        anchor_body = extract_post_body_text(chat.post)
        candidate_post_ids << chat.post.id
        post_context << "POST id=#{chat.post.id} title=#{chat.post.title}\n#{anchor_body.to_s.squish.truncate(ANCHOR_CONTEXT_TRUNCATE_CHARS)}"
      end

      # Embed the user message once and reuse the vector for both the post and
      # the chat-history searches (this used to be two identical embed calls).
      query_embedding = !small_talk && chat.user_message.present? ? service.embed(text: chat.user_message) : nil

      if query_embedding.present?
        vector_literal = vector_literal_for(query_embedding)
        hits = Post.where.not(embedding: nil)
                   .where(status: Post.statuses[:published], verified: true)
                   .order(Arel.sql("embedding <-> '#{vector_literal}'::vector"))
                   .limit(MAX_RAG_HITS)
        hits.each do |p|
          next unless relevant_embedding?(query_embedding, p.embedding)
          next if chat.post.present? && p.id == chat.post.id

          candidate_post_ids << p.id
          body_text = extract_post_body_text(p)
          post_context << "POST id=#{p.id} title=#{p.title}\n#{body_text.to_s.squish.truncate(RELATED_CONTEXT_TRUNCATE_CHARS)}"
        end
      end

      if query_embedding.present?
        vector_literal = vector_literal_for(query_embedding)
        recent_history_ids = ChatHistory.visible.where(user_id: chat.user_id, chat_session_id: chat.chat_session_id).where("id < ?", chat.id)
                                        .where.not(id: chat.id)
                                        .where.not(bot_response: nil)
                                        .order(created_at: :desc)
                                        .limit(MAX_HISTORY_RAG_POOL)
                                        .pluck(:id)

        history_scope = ChatHistory.where(id: recent_history_ids).where.not(embedding: nil)
        history_hits = if history_scope.exists?
          history_scope.order(Arel.sql("embedding <-> '#{vector_literal}'::vector")).limit(MAX_HISTORY_RAG_HITS)
        else
          ChatHistory.visible.where(user_id: chat.user_id, chat_session_id: chat.chat_session_id).where("id < ?", chat.id)
                     .where.not(id: chat.id)
                     .where.not(embedding: nil)
                     .where.not(bot_response: nil)
                     .order(Arel.sql("embedding <-> '#{vector_literal}'::vector"))
                     .limit(MAX_HISTORY_RAG_HITS)
        end

        history_hits.each do |history|
          next if policy_rejected_history?(history)
          next if candidate_chat_history_ids.include?(history.id)

          candidate_chat_history_ids << history.id
          prompt_context << build_history_context(history)
        end
      end
    rescue StandardError => e
      Rails.logger.error("RAG retrieval failed: #{e.class} - #{e.message}")
    end

    setting = ModerationSetting.current
    system_prompt = setting.assistant_prompt.to_s.presence || ModerationSetting::DEFAULT_ASSISTANT_PROMPT
    assembled_prompt = JSON.generate(
      request: chat.user_message,
      locale: I18n.locale,
      posts: post_context,
      conversation: prompt_context
    )

    result = service.generate(
      prompt: assembled_prompt,
      user: chat.user,
      context: { instructions: system_prompt }
    )

    bot_text = ensure_user_friendly_response(normalize_bot_response(result[:result]))
    unless policy.response_allowed?(message: chat.user_message, answer: bot_text, posts: post_context)
      persist_policy_response(chat, reason: "response_rejected")
      return
    end
    suggested_post_ids = extract_suggested_post_ids(
      raw_text: result[:result],
      normalized_text: bot_text,
      candidate_ids: candidate_post_ids
    )
    provider_meta = result[:meta].is_a?(Hash) ? result[:meta].except(:suggested_post_ids, "suggested_post_ids") : {}
    provider_meta[:suggested_post_ids] = suggested_post_ids if suggested_post_ids.any?

    chat.with_lock do
      return if chat.cleared_at.present? || chat.bot_response.present?
      chat.update!(
      bot_response: bot_text,
      provider: result[:provider],
      provider_meta: provider_meta
    )
    end

    index_chat_history_embedding(chat, service) unless small_talk
    broadcast_chat_update(chat)
  rescue StandardError, SystemStackError => e
    Rails.logger.error("GeneratePostSuggestionJob failed for chat_history_id=#{chat_history_id}: #{e.class} - #{e.message}")
    mark_chat_failed(chat, reason: "LLM_REQUEST_FAILED: #{e.class} - #{e.message}")
  end

  private

  def persist_policy_response(chat, reason:)
    chat.with_lock do
      return if chat.cleared_at.present? || chat.bot_response.present?
      chat.update!(bot_response: I18n.t("shared.ai_chat.scope_refusal"), provider_meta: { assistant_guard: reason })
    end
    broadcast_chat_update(chat)
  end

  def policy_rejected_history?(history)
    history.provider_meta.is_a?(Hash) && history.provider_meta["assistant_guard"].present?
  end

  # `dom_id` helper isn't available in jobs — build the target id explicitly.
  def broadcast_chat_update(chat)
    return if chat.reload.cleared_at.present?

    Turbo::StreamsChannel.broadcast_replace_to(
      "chat_histories_user_#{chat.user_id}",
      target: "chat_history_#{chat.id}",
      partial: "chat_histories/chat_history_item",
      locals: { chat_history: chat }
    )
  rescue StandardError => e
    Rails.logger.warn("GeneratePostSuggestionJob: broadcast failed for chat_history_id=#{chat.id}: #{e.class} - #{e.message}")
  end

  # Terminal failure state: persist a user-friendly message (so the UI stops
  # polling) and record the reason in provider_meta. Retrying via `raise`
  # would be a no-op anyway because perform early-returns once bot_response
  # is present.
  def mark_chat_failed(chat, reason:)
    return unless chat

    chat.reload
    return if chat.bot_response.present?

    updated = chat.update(bot_response: I18n.t("shared.ai_chat.generation_failed"), provider_meta: { error: reason })
    unless updated
      Rails.logger.error(
        "GeneratePostSuggestionJob: could not persist failure for chat_history_id=#{chat.id}: #{chat.errors.full_messages.to_sentence}"
      )
    end

    broadcast_chat_update(chat)
  end

  # Reused for both the post and the chat-history RAG vector searches.
  def vector_literal_for(embedding)
    "[" + embedding.map { |n| n.to_s }.join(",") + "]"
  end

  def extract_post_body_text(post)
    return "" unless post.respond_to?(:body) && post.body.present?

    if post.body.respond_to?(:to_plain_text)
      post.body.to_plain_text
    else
      post.body.to_s
    end
  end

  def build_history_context(chat_history)
    text = chat_history.embedding_text.to_s.squish.truncate(HISTORY_CONTEXT_TRUNCATE_CHARS)
    "CHAT id=#{chat_history.id} post_id=#{chat_history.post_id || 'nil'}\n#{text}"
  end

  def index_chat_history_embedding(chat_history, service)
    embedding_text = chat_history.embedding_text
    return if embedding_text.blank?

    embedding = service.embed(text: embedding_text)
    return if embedding.blank?

    ChatHistory.visible.where(id: chat_history.id).update_all(embedding: embedding, updated_at: Time.current)
  rescue StandardError => e
    Rails.logger.warn("Chat history embedding index failed for chat_history_id=#{chat_history.id}: #{e.class} - #{e.message}")
  end

  def normalize_bot_response(raw_text)
    text = raw_text.to_s
    return text unless looks_like_json?(text)

    parsed = JSON.parse(text)
    return text unless parsed.is_a?(Hash)

    format_json_response(parsed)
  rescue JSON::ParserError
    text
  end

  def looks_like_json?(text)
    stripped = text.strip
    stripped.start_with?("{") && stripped.end_with?("}")
  end

  def format_json_response(payload)
    lines = []
    lines << payload["suggestion"].to_s if payload["suggestion"].present?
    lines << payload["summary"].to_s if payload["summary"].present?

    if payload["draft_snippet"].present?
      lines << "Draft:\n#{payload["draft_snippet"]}"
    end

    actions = payload["actions"]
    if actions.is_a?(Array) && actions.any?
      lines << "Next actions:\n" + actions.map { |item| "- #{item}" }.join("\n")
    end

    refs = payload["references"]
    if refs.is_a?(Array) && refs.any?
      lines << "References: #{refs.map { |id| "##{id}" }.join(", ")}"
    end

    lines.join("\n\n").presence || payload.to_json
  end

  def ensure_user_friendly_response(text)
    cleaned = text.to_s.strip
    return I18n.t("shared.ai_chat.context_missing") if cleaned.blank?

    cleaned
  end

  def small_talk?(message)
    normalized = message.to_s.downcase.gsub(/[\p{P}\p{S}]/, " ").squish
    normalized.match?(/\A(?:hi|hi there|hello|hello there|hey|good morning|good afternoon|good evening|good night|how are you|hello how are you|hi how are you|thanks|thank you|thanks a lot|thank you very much|bye|goodbye|xin chào|chào|chào bạn|cảm ơn|cám ơn|tạm biệt|こんにちは|こんばんは|おはよう|おはようございます|ありがとう|ありがとうございます|さようなら)\z/)
  end

  # Compare directions instead of treating every nearest neighbor as relevant.
  # Keep the indexed L2 ordering, then apply cosine filtering to the bounded hits.
  def relevant_embedding?(query, candidate)
    left = Array(query)
    right = Array(candidate)
    return false if left.empty? || left.size != right.size

    dot = left.zip(right).sum { |a, b| a * b }
    norm = Math.sqrt(left.sum { |a| a * a } * right.sum { |b| b * b })
    norm.positive? && dot / norm >= MIN_POST_SIMILARITY
  end

  def extract_suggested_post_ids(raw_text:, normalized_text:, candidate_ids: [])
    ids = []
    ids.concat(extract_ids_from_json_references(raw_text))
    ids.concat(extract_ids_from_text(raw_text))
    ids.concat(extract_ids_from_text(normalized_text))
    ids = ids.uniq & candidate_ids
    return [] if ids.empty?

    visible_posts_by_id = Post.where(id: ids.uniq, status: Post.statuses[:published], verified: true).index_by(&:id)
    ids.uniq.filter_map { |id| visible_posts_by_id[id]&.id }
  end

  def extract_ids_from_json_references(text)
    stripped = text.to_s.strip
    return [] unless looks_like_json?(stripped)

    payload = JSON.parse(stripped)
    refs = payload["references"]
    return [] unless refs.is_a?(Array)

    refs.filter_map { |value| Integer(value, exception: false) }
  rescue JSON::ParserError
    []
  end

  def extract_ids_from_text(text)
    return [] if text.blank?

    text.to_s.scan(/(?:post\s*#|#)(\d+)/i).flatten.filter_map { |value| Integer(value, exception: false) }
  end
end
