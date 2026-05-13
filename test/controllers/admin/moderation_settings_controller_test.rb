require "test_helper"

class Admin::ModerationSettingsControllerTest < ActionDispatch::IntegrationTest
  test "admin can update moderation settings" do
    admin = User.create!(
      name: "Admin",
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      confirmed_at: Time.current,
      role: :admin
    )

    sign_in admin

    patch admin_moderation_setting_path(locale: :en), params: {
      moderation_setting: {
        provider: "mistral",
        ai_model: "mistral-small-latest",
        auto_approve_threshold: 0.85,
        request_timeout_seconds: 20,
        max_retries: 3,
        auto_review_enabled: true,
        api_key: "test-mistral-key",
        new_post_instruction: "Check new post",
        revision_instruction: "Check revision"
      }
    }

    assert_redirected_to edit_admin_moderation_setting_path(locale: :en)

    setting = ModerationSetting.current
    assert_equal 0.85, setting.auto_approve_threshold
    assert_equal "Check new post", setting.new_post_instruction
  end

  test "admin can switch to different ai provider with api key" do
    admin = User.create!(
      name: "Admin",
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      confirmed_at: Time.current,
      role: :admin
    )

    sign_in admin

    patch admin_moderation_setting_path(locale: :en), params: {
      moderation_setting: {
        provider: "openai",
        api_key: "sk-test-openai",
        ai_model: "gpt-4.1-mini",
        auto_approve_threshold: 0.85,
        request_timeout_seconds: 20,
        max_retries: 3,
        auto_review_enabled: true,
        new_post_instruction: "Check new post",
        revision_instruction: "Check revision"
      }
    }

    assert_redirected_to edit_admin_moderation_setting_path(locale: :en)

    setting = ModerationSetting.current
    assert_equal "openai", setting.provider
    assert_equal "sk-test-openai", setting.api_key
  end

  test "admin can switch provider and retain existing api key" do
    admin = User.create!(
      name: "Admin",
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      confirmed_at: Time.current,
      role: :admin
    )

    sign_in admin

    # First set up with mistral
    setting = ModerationSetting.current
    setting.update!(provider: "mistral", api_key: "existing-mistral-key")

    # Now switch provider while leaving api_key blank (should keep existing key)
    patch admin_moderation_setting_path(locale: :en), params: {
      moderation_setting: {
        provider: "openai",
        api_key: "",
        ai_model: "gpt-4.1-mini",
        auto_approve_threshold: 0.85,
        request_timeout_seconds: 20,
        max_retries: 3,
        auto_review_enabled: true,
        new_post_instruction: "Check new post",
        revision_instruction: "Check revision"
      }
    }

    assert_redirected_to edit_admin_moderation_setting_path(locale: :en)

    setting.reload
    # Provider should be updated
    assert_equal "openai", setting.provider
    # API key should remain unchanged (controller deletes blank api_key param)
    assert_equal "existing-mistral-key", setting.api_key
  end

  test "non admin cannot update moderation settings" do
    author = User.create!(
      name: "Author",
      email: "writer-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      confirmed_at: Time.current,
      role: :author
    )

    sign_in author

    patch admin_moderation_setting_path(locale: :en), params: {
      moderation_setting: {
        provider: "ollama",
        ai_model: "gemma4:latest"
      }
    }

    assert_redirected_to root_path(locale: :en)
  end
end
