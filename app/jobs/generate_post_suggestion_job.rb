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
  FALLBACK_SUGGESTED_POST_LIMIT = ENV.fetch("AI_CHAT_FALLBACK_SUGGESTED_POST_LIMIT", "3").to_i

  def perform(chat_history_id)
    chat = ChatHistory.find_by(id: chat_history_id)
    return unless chat
    return if chat.bot_response.present?
    if chat.created_at < ChatHistory::REQUEST_TTL.ago
      mark_chat_failed(chat, reason: "Request expired before processing")
      return
    end

    service = AiGeneration::Service.new

    # Retrieval-Augmented Generation using pgvector embeddings (if available)
    prompt_context = []
    candidate_post_ids = []
    candidate_chat_history_ids = []
    begin
      # Always anchor on the current post first when available.
      if chat.post.present?
        anchor_body = extract_post_body_text(chat.post)
        candidate_post_ids << chat.post.id
        prompt_context << "POST id=#{chat.post.id} title=#{chat.post.title}\n#{anchor_body.to_s.squish.truncate(ANCHOR_CONTEXT_TRUNCATE_CHARS)}"
      end

      # Embed the user message once and reuse the vector for both the post and
      # the chat-history searches (this used to be two identical embed calls).
      query_embedding = chat.user_message.present? ? service.embed(text: chat.user_message) : nil

      if query_embedding.present?
        vector_literal = vector_literal_for(query_embedding)
        hits = Post.where.not(embedding: nil)
                   .where(status: Post.statuses[:published], verified: true)
                   .order(Arel.sql("embedding <-> '#{vector_literal}'::vector"))
                   .limit(MAX_RAG_HITS)
        hits.each do |p|
          next if chat.post.present? && p.id == chat.post.id

          candidate_post_ids << p.id
          body_text = extract_post_body_text(p)
          prompt_context << "POST id=#{p.id} title=#{p.title}\n#{body_text.to_s.squish.truncate(RELATED_CONTEXT_TRUNCATE_CHARS)}"
        end
      end

      if query_embedding.present?
        vector_literal = vector_literal_for(query_embedding)
        recent_history_ids = ChatHistory.where(user_id: chat.user_id)
                                        .where.not(id: chat.id)
                                        .where.not(bot_response: nil)
                                        .order(created_at: :desc)
                                        .limit(MAX_HISTORY_RAG_POOL)
                                        .pluck(:id)

        history_scope = ChatHistory.where(id: recent_history_ids).where.not(embedding: nil)
        history_hits = if history_scope.exists?
          history_scope.order(Arel.sql("embedding <-> '#{vector_literal}'::vector")).limit(MAX_HISTORY_RAG_HITS)
        else
          ChatHistory.where(user_id: chat.user_id)
                     .where.not(id: chat.id)
                     .where.not(embedding: nil)
                     .where.not(bot_response: nil)
                     .order(Arel.sql("embedding <-> '#{vector_literal}'::vector"))
                     .limit(MAX_HISTORY_RAG_HITS)
        end

        history_hits.each do |history|
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
    grounding_rules = <<~RULES
      Grounding Rules:
      - Use ONLY facts present in Context.
      - If Context does not contain enough information, say so explicitly.
      - Do not invent post titles, IDs, metrics, or claims.
      - Keep the response concise, helpful, and user-friendly.
      - Start with a direct answer sentence, then short bullets only if needed.
      - Return plain text (markdown allowed), not JSON.
      - If useful, mention references inline like: "Based on post #22".
    RULES

    assembled_prompt = [
      system_prompt,
      grounding_rules,
      "Context:\n#{prompt_context.join("\n\n")}",
      "User:\n#{chat.user_message}"
    ].join("\n\n")

    result = service.generate(
      prompt: assembled_prompt,
      user: chat.user
    )

    bot_text = ensure_user_friendly_response(normalize_bot_response(result[:result]))
    suggested_post_ids = extract_suggested_post_ids(
      raw_text: result[:result],
      normalized_text: bot_text,
      fallback_ids: candidate_post_ids
    )
    provider_meta = result[:meta].is_a?(Hash) ? result[:meta].dup : {}
    provider_meta[:suggested_post_ids] = suggested_post_ids if suggested_post_ids.any?

    chat.update!(
      bot_response: bot_text,
      provider: result[:provider],
      provider_meta: provider_meta
    )

    index_chat_history_embedding(chat, service)
    broadcast_chat_update(chat)
  rescue StandardError => e
    Rails.logger.error("GeneratePostSuggestionJob failed for chat_history_id=#{chat_history_id}: #{e.class} - #{e.message}")
    mark_chat_failed(chat, reason: "LLM_REQUEST_FAILED: #{e.class} - #{e.message}")
  end

  private

  # `dom_id` helper isn't available in jobs — build the target id explicitly.
  def broadcast_chat_update(chat)
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

    updated = chat.update(bot_response: GENERATION_FAILED_MESSAGE, provider_meta: { error: reason })
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

    chat_history.update_columns(embedding: embedding, updated_at: Time.current)
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
    return "I could not find enough context to make a confident suggestion yet. Please share a bit more detail so I can help better." if cleaned.blank?

    cleaned
  end

  def extract_suggested_post_ids(raw_text:, normalized_text:, fallback_ids: [])
    ids = []
    ids.concat(extract_ids_from_json_references(raw_text))
    ids.concat(extract_ids_from_text(raw_text))
    ids.concat(extract_ids_from_text(normalized_text))
    ids = fallback_ids.first(FALLBACK_SUGGESTED_POST_LIMIT) if ids.empty?

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
