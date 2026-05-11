if defined?(RubyLLM) && RubyLLM.respond_to?(:configure)
  RubyLLM.configure do |config|
    config.ollama_api_base = ENV.fetch("OLLAMA_API_BASE", "http://127.0.0.1:11434/v1")
  end
end
