module AiGeneration
  class Service
    TARGET_EMBEDDING_DIM = (ENV["AI_EMBEDDING_DIM"].presence || "1536").to_i

    DEFAULT_EMBEDDING_MODELS = {
      ModerationSetting::PROVIDERS[:openai] => "text-embedding-3-small",
      ModerationSetting::PROVIDERS[:gemini] => "gemini-embedding-001",
      ModerationSetting::PROVIDERS[:mistral] => "mistral-embed-2312"
    }.freeze

    def initialize(config: AiModeration::Configuration.current)
      @config = config
    end

    def generate(prompt:, user:, context: {})
      configure_ruby_llm!

      provider = provider_for_ruby_llm(@config.fetch(:provider))
      model = @config.fetch(:model_name)

      chat = RubyLLM.chat(model: model, provider: provider)
      response = chat.ask(prompt)
      result_text = extract_text(response)

      {
        provider: @config.fetch(:provider),
        result: result_text,
        meta: { raw_response: response }
      }
    rescue StandardError => e
      Rails.logger.error("AiGeneration::Service failed: #{e.class} - #{e.message}")
      raise
    end

    def embed(text:)
      configure_ruby_llm!

      provider = @config.fetch(:provider)
      if provider == ModerationSetting::PROVIDERS[:claude]
        raise ArgumentError, "Embeddings are not supported for provider: #{provider}. Use openai, gemini, or mistral."
      end

      # Try per-provider env var first, then general override, then default
      env_var_key = "AI_EMBEDDING_MODEL_#{provider.upcase}"
      embedding_model = ENV[env_var_key].presence || ENV["AI_EMBEDDING_MODEL"].presence || DEFAULT_EMBEDDING_MODELS[provider]
      raise ArgumentError, "No embedding model configured for provider: #{provider}" if embedding_model.blank?

      response = RubyLLM.embed(
        text,
        model: embedding_model,
        provider: provider_for_ruby_llm(provider)
      )

      vector = extract_embedding_vector(response)
      normalize_embedding_dimensions(vector)
    rescue StandardError => e
      Rails.logger.error("AiGeneration::Service embed failed: #{e.class} - #{e.message}")
      raise
    end

    private

    def configure_ruby_llm!
      return unless defined?(RubyLLM) && RubyLLM.respond_to?(:configure)

      RubyLLM.configure do |llm_config|
        if llm_config.respond_to?(:request_timeout=)
          llm_config.request_timeout = @config.fetch(:request_timeout_seconds).to_i
        end

        provider = @config.fetch(:provider)
        api_key = @config[:api_key]
        next if api_key.blank?

        case provider
        when ModerationSetting::PROVIDERS[:openai]
          llm_config.openai_api_key = api_key if llm_config.respond_to?(:openai_api_key=)
        when ModerationSetting::PROVIDERS[:gemini]
          if llm_config.respond_to?(:gemini_api_key=)
            llm_config.gemini_api_key = api_key
          elsif llm_config.respond_to?(:google_api_key=)
            llm_config.google_api_key = api_key
          end
        when ModerationSetting::PROVIDERS[:claude]
          llm_config.anthropic_api_key = api_key if llm_config.respond_to?(:anthropic_api_key=)
        when ModerationSetting::PROVIDERS[:mistral]
          llm_config.mistral_api_key = api_key if llm_config.respond_to?(:mistral_api_key=)
        end
      end
    end

    def provider_for_ruby_llm(provider)
      case provider
      when ModerationSetting::PROVIDERS[:claude]
        :anthropic
      else
        provider.to_sym
      end
    end

    def extract_text(response)
      return response.content if response.respond_to?(:content)

      response.to_s
    end

    def extract_embedding_vector(response)
      if response.respond_to?(:vectors)
        vectors = response.vectors
        return vectors.first if vectors.is_a?(Array) && vectors.first.is_a?(Array)
        return vectors if vectors.is_a?(Array)
      end

      if response.is_a?(Hash)
        vector = response[:embedding] || response["embedding"]
        return vector if vector.is_a?(Array)
      end

      return response if response.is_a?(Array)

      raise ArgumentError, "Unexpected embedding response format: #{response.class.name}"
    end

    def normalize_embedding_dimensions(vector)
      arr = Array(vector).map(&:to_f)
      return arr if TARGET_EMBEDDING_DIM <= 0

      if arr.length > TARGET_EMBEDDING_DIM
        arr.first(TARGET_EMBEDDING_DIM)
      elsif arr.length < TARGET_EMBEDDING_DIM
        arr + Array.new(TARGET_EMBEDDING_DIM - arr.length, 0.0)
      else
        arr
      end
    end
  end
end
