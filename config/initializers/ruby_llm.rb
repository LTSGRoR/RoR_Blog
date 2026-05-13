if defined?(RubyLLM) && RubyLLM.respond_to?(:configure)
  RubyLLM.configure do |config|
    # Configure RubyLLM for supported providers: mistral, openai, gemini, claude
    # Provider-specific API keys are configured by AiModeration::Client
  end
end
