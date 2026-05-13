require "test_helper"

class AiModeration::ConfigurationTest < ActiveSupport::TestCase
  setup do
    ModerationSetting.delete_all
  end

  test "uses encrypted setting api key when provider env key is not set" do
    setting = ModerationSetting.current
    setting.update!(provider: "openai", api_key: "stored-openai-key")

    config = with_env("OPENAI_API_KEY" => nil, "AI_MODERATION_PROVIDER" => nil) do
      AiModeration::Configuration.current
    end

    assert_equal "openai", config[:provider]
    assert_equal "stored-openai-key", config[:api_key]
  end

  test "stored api key overrides env api key" do
    setting = ModerationSetting.current
    setting.update!(provider: "openai", api_key: "stored-openai-key")

    config = with_env("OPENAI_API_KEY" => "env-openai-key") do
      AiModeration::Configuration.current
    end

    assert_equal "stored-openai-key", config[:api_key]
  end

  test "db moderation settings override env moderation settings" do
    setting = ModerationSetting.current
    setting.update!(
      provider: "mistral",
      ai_model: "mistral-small-latest",
      auto_approve_threshold: 0.85,
      request_timeout_seconds: 20,
      max_retries: 2,
      auto_review_enabled: false,
      api_key: "test-api-key"
    )

    config = with_env(
      "AI_MODERATION_PROVIDER" => "openai",
      "AI_MODERATION_MODEL" => "gemma4:latest",
      "AI_MODERATION_AUTO_APPROVE_THRESHOLD" => "0.99",
      "AI_MODERATION_TIMEOUT_SECONDS" => "90",
      "AI_MODERATION_MAX_RETRIES" => "9",
      "AI_MODERATION_ENABLED" => "true"
    ) do
      AiModeration::Configuration.current
    end

    assert_equal "mistral", config[:provider]
    assert_equal "mistral-small-latest", config[:model_name]
    assert_equal 0.85, config[:auto_approve_threshold]
    assert_equal 20, config[:request_timeout_seconds]
    assert_equal 2, config[:max_retries]
    assert_equal false, config[:auto_review_enabled]
  end

  test "env api key is used when stored key is blank" do
    setting = ModerationSetting.current
    setting.update!(provider: "openai", api_key: "stored-openai-key")
    setting.update_columns(api_key: nil)

    config = with_env("OPENAI_API_KEY" => "env-openai-key") do
      AiModeration::Configuration.current
    end

    assert_equal "env-openai-key", config[:api_key]
  end

  test "mistral uses provider-specific env api key when stored key is blank" do
    setting = ModerationSetting.current
    setting.update!(provider: "mistral", api_key: "stored-mistral-key")
    setting.update_columns(api_key: nil)

    config = with_env("MISTRAL_API_KEY" => "env-mistral-key") do
      AiModeration::Configuration.current
    end

    assert_equal "mistral", config[:provider]
    assert_equal "env-mistral-key", config[:api_key]
  end

  private

  def with_env(changes)
    original = {}
    changes.each do |key, value|
      original[key] = ENV.key?(key) ? ENV[key] : :__undefined
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end

    yield
  ensure
    original.each do |key, value|
      value == :__undefined ? ENV.delete(key) : ENV[key] = value
    end
  end
end
