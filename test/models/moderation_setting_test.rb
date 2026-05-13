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

  test "requires api key for all providers" do
    setting = ModerationSetting.current
    setting.provider = "openai"
    setting.api_key = nil

    assert_not setting.valid?
    assert_includes setting.errors[:api_key], "can't be blank"
  end

  test "requires api key for mistral provider" do
    setting = ModerationSetting.current
    setting.provider = "mistral"
    setting.api_key = nil

    assert_not setting.valid?
    assert_includes setting.errors[:api_key], "can't be blank"
  end
end
