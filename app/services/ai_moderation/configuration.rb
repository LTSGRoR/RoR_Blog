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
        provider = env_or_setting(:provider, setting.provider).to_s

        {
          provider: provider,
          model_name: env_or_setting(:model_name, setting.ai_model),
          auto_approve_threshold: env_or_setting(:auto_approve_threshold, setting.auto_approve_threshold).to_f,
          request_timeout_seconds: env_or_setting(:request_timeout_seconds, setting.request_timeout_seconds).to_i,
          max_retries: env_or_setting(:max_retries, setting.max_retries).to_i,
          auto_review_enabled: parse_boolean(env_or_setting(:auto_review_enabled, setting.auto_review_enabled)),
          new_post_instruction: setting.new_post_instruction,
          revision_instruction: setting.revision_instruction,
          api_key: provider_api_key(provider: provider, setting: setting)
        }
      end

      private

      # Deployment-level ENV vars win over the database row so containerized
      # deployments behave as documented in the README/.env.example; the
      # admin-editable ModerationSetting row is the fallback. (Previously the
      # seeded DB defaults always won, silently ignoring these ENV keys.)
      def env_or_setting(key, setting_value)
        ENV[ENV_KEYS.fetch(key)].presence || setting_value
      end

      def parse_boolean(value)
        ActiveModel::Type::Boolean.new.cast(value)
      end

      # An admin-saved API key always wins: rotating the key via the admin UI
      # must not be silently overridden by a stale ENV value.
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
