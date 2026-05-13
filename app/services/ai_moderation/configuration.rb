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

    PROVIDER_API_KEY_ENV = {
      "openai" => "OPENAI_API_KEY",
      "gemini" => "GEMINI_API_KEY",
      "claude" => "ANTHROPIC_API_KEY",
      "mistral" => "MISTRAL_API_KEY"
    }.freeze

    class << self
      def current
        setting = ModerationSetting.current
        provider = setting_or_env(setting.provider, :provider).to_s

        {
          provider: provider,
          model_name: setting_or_env(setting.ai_model, :model_name),
          auto_approve_threshold: setting_or_env(setting.auto_approve_threshold, :auto_approve_threshold).to_f,
          request_timeout_seconds: setting_or_env(setting.request_timeout_seconds, :request_timeout_seconds).to_i,
          max_retries: setting_or_env(setting.max_retries, :max_retries).to_i,
          auto_review_enabled: parse_boolean(setting_or_env(setting.auto_review_enabled, :auto_review_enabled)),
          new_post_instruction: setting.new_post_instruction,
          revision_instruction: setting.revision_instruction,
          api_key: provider_api_key(provider: provider, setting: setting)
        }
      end

      private

      def setting_or_env(setting_value, key)
        return setting_value unless setting_value.nil?

        ENV.fetch(ENV_KEYS.fetch(key), setting_value)
      end

      def parse_boolean(value)
        ActiveModel::Type::Boolean.new.cast(value)
      end

      def provider_api_key(provider:, setting:)
        return setting.api_key if setting.api_key.present?

        env_key = PROVIDER_API_KEY_ENV[provider]
        env_value = env_key.present? ? ENV[env_key] : nil

        return env_value if env_value.present?

        setting.api_key
      end
    end
  end
end
