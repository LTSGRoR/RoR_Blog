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
        provider: "ollama",
        ai_model: "gemma4:latest",
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
    assert_equal 0.85, setting.auto_approve_threshold
    assert_equal "Check new post", setting.new_post_instruction
  end

  test "admin can switch to non-ollama provider with api key" do
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

  test "admin cannot switch to non-ollama provider without api key" do
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

    assert_response :unprocessable_entity
    assert_match(/api key.*blank/i, response.body)
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
