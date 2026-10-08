require "test_helper"

class ChatGenerationTest < ActiveSupport::TestCase
  def permitted_service
    service = Object.new
    service.define_singleton_method(:policy_decision) do |schema:, **_|
      schema[:properties].key?(:category) ? { "category" => "blog_content" } : { "allowed" => true }
    end
    service
  end

  setup do
    @chat = ChatHistory.create!(user: create_user, user_message: "Help me")
  end

  test "generation failures use the queued request locale and restore worker locale" do
    service = permitted_service
    service.define_singleton_method(:embed) { |**_| nil }
    service.define_singleton_method(:generate) { |**_| raise "Provider unavailable" }
    %i[en vi ja].each do |locale|
      chat = ChatHistory.create!(user: @chat.user, user_message: "Hello")
      previous_locale = I18n.locale
      AiGeneration::Service.stub(:new, service) { GeneratePostSuggestionJob.perform_now(chat.id, locale.to_s) }
      assert_equal I18n.t("shared.ai_chat.generation_failed", locale: locale), chat.reload.bot_response
      assert_equal previous_locale, I18n.locale
    end
  end

  test "conversation context excludes messages from other sessions" do
    ChatHistory.create!(user: @chat.user, chat_session: @chat.chat_session,
      user_message: "Remember purple bicycles", bot_response: "Purple bicycles remembered")
    other = @chat.user.chat_sessions.create!(title: "Other")
    ChatHistory.create!(user: @chat.user, chat_session: other,
      user_message: "Private orange submarines", bot_response: "Orange submarines remembered")
    next_message = ChatHistory.create!(user: @chat.user, chat_session: @chat.chat_session, user_message: "What did I say?")
    captured = nil
    service = permitted_service
    service.define_singleton_method(:embed) { |**_| nil }
    service.define_singleton_method(:generate) do |prompt:, **_|
      captured = prompt
      { result: "Purple bicycles", provider: "test", meta: {} }
    end
    AiGeneration::Service.stub(:new, service) { GeneratePostSuggestionJob.perform_now(next_message.id) }
    assert_includes captured, "purple bicycles"
    assert_not_includes captured, "orange submarines"
    assert_equal "Purple bicycles", next_message.reload.bot_response
  end

  test "deleting a session during generation cannot restore cleared content" do
    service = permitted_service
    session = @chat.chat_session
    service.define_singleton_method(:embed) { |**_| nil }
    service.define_singleton_method(:generate) do |**_|
      session.with_lock do
        session.clear_messages!
        session.update!(deleted_at: Time.current, title: nil)
      end
      { result: "Late answer", provider: "test", meta: {} }
    end
    AiGeneration::Service.stub(:new, service) { GeneratePostSuggestionJob.perform_now(@chat.id) }
    assert_equal "[cleared]", @chat.reload.bot_response
    assert_nil @chat.provider_meta
    assert_nil @chat.embedding
  end

  test "greetings in all languages skip embeddings and blog cards" do
    [ "HELLO! 👋", "Xin chào!", "こんにちは！", "Thank you" ].each do |message|
      chat = ChatHistory.create!(user: @chat.user, user_message: message)
      service = permitted_service
      service.define_singleton_method(:embed) { |**_| raise "Greeting must not request embeddings" }
      service.define_singleton_method(:generate) { |**_| { result: "Hello! How can I help?", provider: "test", meta: {} } }
      AiGeneration::Service.stub(:new, service) { GeneratePostSuggestionJob.perform_now(chat.id) }
      assert_equal "Hello! How can I help?", chat.reload.bot_response
      assert_empty chat.suggested_post_ids
      assert_nil chat.embedding
    end
  end

  test "weak matches are excluded and retrieved posts require a citation for cards" do
    relevant = create_post(user: @chat.user, verified: true)
    unrelated = create_post(user: @chat.user, verified: true)
    unrelated.update!(title: "Unrelated topic")
    query_vector = [ 1.0 ] + Array.new(1535, 0.0)
    irrelevant_vector = [ 0.0, 1.0 ] + Array.new(1534, 0.0)
    relevant.update_columns(embedding: query_vector)
    unrelated.update_columns(embedding: irrelevant_vector)
    captured = nil
    answer = "Here is a useful answer without a post citation."
    service = permitted_service
    service.define_singleton_method(:embed) { |**_| query_vector }
    service.define_singleton_method(:generate) do |prompt:, **_|
      captured = prompt
      { result: answer, provider: "test", meta: {} }
    end
    AiGeneration::Service.stub(:new, service) { GeneratePostSuggestionJob.perform_now(@chat.id) }
    assert_includes captured, "POST id=#{relevant.id} title="
    assert_not_includes captured, "POST id=#{unrelated.id} title="
    assert_empty @chat.reload.suggested_post_ids

    next_chat = ChatHistory.create!(user: @chat.user, user_message: "Explain this topic")
    answer = "Based on post ##{relevant.id}, here is the explanation. Also post ##{unrelated.id}."
    AiGeneration::Service.stub(:new, service) { GeneratePostSuggestionJob.perform_now(next_chat.id) }
    assert_equal [ relevant.id ], next_chat.reload.suggested_post_ids
  end

  test "provider object with circular references is never persisted" do
    response = Struct.new(:content, :raw).new("Safe answer")
    response.raw = response
    client = Object.new
    client.define_singleton_method(:ask) { |_prompt| response }
    client.define_singleton_method(:with_instructions) { |_instructions| self }
    service = AiGeneration::Service.new(config: { provider: "mistral", model_name: "test", request_timeout_seconds: 10 })
    RubyLLM.stub(:chat, client) do
      service.stub(:embed, nil) do
        service.stub(:policy_decision, ->(schema:, **_) { schema[:properties].key?(:category) ? { "category" => "blog_content" } : { "allowed" => true } }) do
          AiGeneration::Service.stub(:new, service) { GeneratePostSuggestionJob.perform_now(@chat.id) }
        end
      end
    end
    assert_equal "Safe answer", @chat.reload.bot_response
    assert_equal "test", @chat.provider_meta.fetch("model")
    assert_not @chat.provider_meta.key?("raw_response")
  end

  test "stack errors persist a terminal response" do
    service = permitted_service
    service.define_singleton_method(:embed) { |**_| nil }
    service.define_singleton_method(:generate) { |**_| raise SystemStackError, "stack level too deep" }
    AiGeneration::Service.stub(:new, service) { GeneratePostSuggestionJob.perform_now(@chat.id) }
    assert_equal GeneratePostSuggestionJob::GENERATION_FAILED_MESSAGE, @chat.reload.bot_response
    assert_match "SystemStackError", @chat.provider_meta.fetch("error")
  end

  test "dirty circular metadata is discarded before failure persistence" do
    metadata = {}
    metadata[:loop] = metadata
    service = permitted_service
    service.define_singleton_method(:embed) { |**_| nil }
    service.define_singleton_method(:generate) { |**_| { provider: "mistral", result: "Answer", meta: metadata } }
    AiGeneration::Service.stub(:new, service) { GeneratePostSuggestionJob.perform_now(@chat.id) }
    assert_equal GeneratePostSuggestionJob::GENERATION_FAILED_MESSAGE, @chat.reload.bot_response
    assert_match "JSON::NestingError", @chat.provider_meta.fetch("error")
  end
end
