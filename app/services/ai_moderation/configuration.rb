module AiModeration
  class Configuration
    ENV_KEYS = {
      provider: "AI_MODERATION_PROVIDER",
      model_name: "AI_MODERATION_MODEL",
      auto_approve_threshold: "AI_MODERATION_AUTO_APPROVE_THRESHOLD",
      request_timeout_seconds: "AI_MODERATION_TIMEOUT_SECONDS",
      max_retries: "AI_MODERATION_MAX_RETRIES",
      auto_review_enabled: "AI_MODERATION_ENABLED"
    }.freeze

    class << self
      def current
        setting = ModerationSetting.current

        {
          provider: env_or_default(:provider, setting.provider),
          model_name: env_or_default(:model_name, setting.ai_model),
          auto_approve_threshold: env_or_default(:auto_approve_threshold, setting.auto_approve_threshold).to_f,
          request_timeout_seconds: env_or_default(:request_timeout_seconds, setting.request_timeout_seconds).to_i,
          max_retries: env_or_default(:max_retries, setting.max_retries).to_i,
          auto_review_enabled: parse_boolean(env_or_default(:auto_review_enabled, setting.auto_review_enabled)),
          new_post_instruction: setting.new_post_instruction,
          revision_instruction: setting.revision_instruction,
          ollama_api_base: ENV.fetch("OLLAMA_API_BASE", "http://127.0.0.1:11434/v1")
        }
      end

      private

      def env_or_default(key, fallback)
        ENV.fetch(ENV_KEYS.fetch(key), fallback)
      end

      def parse_boolean(value)
        ActiveModel::Type::Boolean.new.cast(value)
      end
    end
  end
end
