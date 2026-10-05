require "test_helper"

class ChatGenerationTest < ActiveSupport::TestCase
  setup do
    @chat = ChatHistory.create!(user: create_user, user_message: "Help me")
  end

  test "provider object with circular references is never persisted" do
    response = Struct.new(:content, :raw).new("Safe answer")
    response.raw = response
    client = Object.new
    client.define_singleton_method(:ask) { |_prompt| response }
    service = AiGeneration::Service.new(config: { provider: "mistral", model_name: "test", request_timeout_seconds: 10 })
    RubyLLM.stub(:chat, client) do
      service.stub(:embed, nil) do
        AiGeneration::Service.stub(:new, service) { GeneratePostSuggestionJob.perform_now(@chat.id) }
      end
    end
    assert_equal "Safe answer", @chat.reload.bot_response
    assert_equal "test", @chat.provider_meta.fetch("model")
    assert_not @chat.provider_meta.key?("raw_response")
  end

  test "stack errors persist a terminal response" do
    service = Object.new
    service.define_singleton_method(:embed) { |**_| nil }
    service.define_singleton_method(:generate) { |**_| raise SystemStackError, "stack level too deep" }
    AiGeneration::Service.stub(:new, service) { GeneratePostSuggestionJob.perform_now(@chat.id) }
    assert_equal GeneratePostSuggestionJob::GENERATION_FAILED_MESSAGE, @chat.reload.bot_response
    assert_match "SystemStackError", @chat.provider_meta.fetch("error")
  end

  test "dirty circular metadata is discarded before failure persistence" do
    metadata = {}
    metadata[:loop] = metadata
    service = Object.new
    service.define_singleton_method(:embed) { |**_| nil }
    service.define_singleton_method(:generate) { |**_| { provider: "mistral", result: "Answer", meta: metadata } }
    AiGeneration::Service.stub(:new, service) { GeneratePostSuggestionJob.perform_now(@chat.id) }
    assert_equal GeneratePostSuggestionJob::GENERATION_FAILED_MESSAGE, @chat.reload.bot_response
    assert_match "JSON::NestingError", @chat.provider_meta.fetch("error")
  end
end
