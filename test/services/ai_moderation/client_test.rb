require "test_helper"

class AiModeration::ClientTest < ActiveSupport::TestCase
  test "maps claude provider to anthropic for RubyLLM" do
    config = {
      provider: "claude",
      model_name: "claude-3-5-sonnet-latest",
      api_key: "anthropic-key",
      auto_approve_threshold: 0.8,
      ollama_api_base: "http://127.0.0.1:11434/v1"
    }

    captured_provider = nil
    fake_response = Struct.new(:content).new({ verdict: "needs_admin_review", confidence: 0.5, risk_score: 0.5, reason: "test" }.to_json)
    fake_chat = Struct.new(:response) do
      def ask(_prompt)
        response
      end
    end.new(fake_response)

    original_configure = RubyLLM.method(:configure)
    original_chat = RubyLLM.method(:chat)
    fake_llm_config = Struct.new(
      :ollama_api_base,
      :openai_api_key,
      :gemini_api_key,
      :google_api_key,
      :anthropic_api_key,
      keyword_init: true
    ).new
    RubyLLM.define_singleton_method(:configure) { |_ = nil, &block| block&.call(fake_llm_config) }
    RubyLLM.define_singleton_method(:chat) { |model:, provider:| captured_provider = provider; fake_chat }

    decision = AiModeration::Client.new(config: config).review(instruction: "Check", content_payload: { body: "x" })
    assert_equal :needs_admin_review, decision.status
  ensure
    RubyLLM.define_singleton_method(:configure, original_configure)
    RubyLLM.define_singleton_method(:chat, original_chat)

    assert_equal :anthropic, captured_provider
  end

  test "returns failed decision when non-ollama provider has no api key" do
    config = {
      provider: "openai",
      model_name: "gpt-4.1-mini",
      api_key: nil,
      auto_approve_threshold: 0.8,
      ollama_api_base: "http://127.0.0.1:11434/v1"
    }

    decision = AiModeration::Client.new(config: config).review(instruction: "Check", content_payload: { body: "x" })

    assert_equal :failed, decision.status
    assert_includes decision.reason, "API key is missing"
  end
end
