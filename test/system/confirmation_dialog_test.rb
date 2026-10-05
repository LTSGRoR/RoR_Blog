require "application_system_test_case"

class ConfirmationDialogTest < ApplicationSystemTestCase
  test "Turbo confirmations are localized and cancel preserves the action" do
    admin = create_user(role: :admin)
    tag = Tag.create!(name: "confirmationneedle")
    visit new_user_session_path(locale: :en)
    fill_in "Email", with: admin.email
    fill_in "Password", with: "secure-password-123"
    click_button "Sign in"
    assert_no_selector "#user_email"

    %i[en vi ja].each do |locale|
      visit edit_admin_tag_path(tag, locale: locale)
      click_button I18n.t("admin.tags.delete", locale: locale)
      within "dialog[open]" do
        assert_text I18n.t("dialogs.confirm.title", locale: locale)
        assert_button I18n.t("dialogs.confirm.ok", locale: locale)
        assert_button I18n.t("dialogs.confirm.cancel", locale: locale), focused: true
        find('[data-confirm-action="cancel"]').send_keys(:escape)
      end
      assert_no_selector "dialog[open]"
      assert Tag.exists?(tag.id)
    end

    click_button I18n.t("admin.tags.delete", locale: :ja)
    within "dialog[open]" do
      click_button I18n.t("dialogs.confirm.ok", locale: :ja)
    end
    assert_no_selector "dialog[open]"
    assert_selector "h1", text: I18n.t("admin.tags.title", locale: :ja)
    assert_not Tag.exists?(tag.id)
  end
end
