require "test_helper"

class ModerationSettingTest < ActiveSupport::TestCase
  setup do
    ModerationSetting.delete_all
  end

  test "requires provider in allowlist" do
    setting = ModerationSetting.current
    setting.provider = "invalid"

    assert_not setting.valid?
    assert_includes setting.errors[:provider], "is not included in the list"
  end

  test "requires api key for non-ollama providers" do
    setting = ModerationSetting.current
    setting.provider = "openai"
    setting.api_key = nil

    assert_not setting.valid?
    assert_includes setting.errors[:api_key], "can't be blank"
  end

  test "does not require api key for ollama" do
    setting = ModerationSetting.current
    setting.provider = "ollama"
    setting.api_key = nil

    assert setting.valid?
  end

  test "queues ollama pull when model changes and provider is ollama" do
    setting = ModerationSetting.current
    setting.update!(provider: "ollama", ai_model: "gemma4:latest")

    called_model = nil
    original_perform_later = PullOllamaModelJob.method(:perform_later)
    PullOllamaModelJob.define_singleton_method(:perform_later) { |model_name| called_model = model_name }

    setting.update!(ai_model: "gemma3:latest")
  ensure
    PullOllamaModelJob.define_singleton_method(:perform_later, original_perform_later)

    assert_equal "gemma3:latest", called_model
  end

  test "does not queue ollama pull when provider is not ollama" do
    setting = ModerationSetting.current
    setting.update!(provider: "openai", api_key: "sk-test", ai_model: "gpt-4.1-mini")

    called = false
    original_perform_later = PullOllamaModelJob.method(:perform_later)
    PullOllamaModelJob.define_singleton_method(:perform_later) { |_model_name| called = true }

    setting.update!(ai_model: "gpt-4.1")
  ensure
    PullOllamaModelJob.define_singleton_method(:perform_later, original_perform_later)

    assert_equal false, called
  end
end
