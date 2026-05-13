module AiModeration
  class Client
    RESPONSE_SCHEMA = {
      verdict: "auto_approve or needs_admin_review",
      confidence: "float from 0 to 1",
      risk_score: "float from 0 to 1 where higher means riskier",
      reason: "short string reason"
    }.freeze

    def initialize(config: Configuration.current)
      @config = config
    end

    def review(instruction:, content_payload:)
      validate_provider_configuration!
      configure_ruby_llm!

      prompt = <<~PROMPT
        #{instruction}

        Return strict JSON only with keys: #{RESPONSE_SCHEMA.keys.join(", ")}.
        JSON schema expectations:
        #{RESPONSE_SCHEMA.to_json}

        Content payload:
        #{content_payload.to_json}
      PROMPT

      provider = provider_for_ruby_llm(@config.fetch(:provider))
      chat = RubyLLM.chat(model: @config.fetch(:model_name), provider: provider)
      response = chat.ask(prompt)
      response_text = extract_text(response)

      DecisionParser.parse(raw_text: response_text, threshold: @config.fetch(:auto_approve_threshold))
    rescue StandardError => e
      DecisionParser::Decision.new(
        status: :failed,
        confidence: nil,
        risk_score: nil,
        reason: e.message,
        payload: { "error_class" => e.class.name, "error_message" => e.message }
      )
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

    def validate_provider_configuration!
      provider = @config.fetch(:provider)
      supported = ModerationSetting::PROVIDERS.values
      raise ArgumentError, "Unsupported AI provider: #{provider}" unless supported.include?(provider)

      raise ArgumentError, "API key is missing for provider: #{provider}" if @config[:api_key].blank?
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
  end
end
