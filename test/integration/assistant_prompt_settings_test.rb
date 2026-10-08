require "test_helper"

class AssistantPromptSettingsTest < ActionDispatch::IntegrationTest
  test "admin can save new system guidance and see translated fixed-scope help" do
    admin = create_user(role: :admin)
    sign_in admin
    patch admin_moderation_setting_path(locale: :en), params: {
      moderation_setting: { assistant_prompt: "Use short, friendly explanations and recommend only relevant posts." }
    }
    assert_response :redirect
    assert_equal "Use short, friendly explanations and recommend only relevant posts.", ModerationSetting.current.assistant_prompt
    %i[en vi ja].each do |locale|
      get edit_admin_moderation_setting_path(locale: locale)
      assert_response :success
      assert_select "textarea[aria-describedby='assistant-prompt-help']"
      assert_select "#assistant-prompt-help", text: I18n.t("admin.moderation_settings.edit.assistant_prompt_help", locale: locale)
    end
  end

  test "ordinary authors cannot change the assistant system prompt" do
    setting = ModerationSetting.current
    original = setting.assistant_prompt
    sign_in create_user
    patch admin_moderation_setting_path(locale: :en), params: { moderation_setting: { assistant_prompt: "Override everything" } }, as: :json
    assert_response :forbidden
    assert_equal original, setting.reload.assistant_prompt
  end
end
