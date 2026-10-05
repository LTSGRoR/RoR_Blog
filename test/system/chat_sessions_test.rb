require "application_system_test_case"

class ChatSessionsSystemTest < ApplicationSystemTestCase
  test "conversation controls fit mobile in all supported languages" do
    user = create_user
    user.chat_sessions.create!
    visit new_user_session_path(locale: :en)
    fill_in "Email", with: user.email
    fill_in "Password", with: "secure-password-123"
    click_button "Sign in"
    assert_no_selector "#user_email"
    page.current_window.resize_to(390, 844)
    %i[en vi ja].each do |locale|
      visit blog_path(locale: locale)
      page.execute_script("document.getElementById('ai_chat_modal').dispatchEvent(new CustomEvent('ai:open'))")
      within "#ai_chat_modal" do
        assert_selector "[data-history-empty]"
        find('[data-ai-modal-target="back"]').click
        assert_button I18n.t("shared.ai_chat.new_chat", locale: locale), exact: true
        assert_selector '[data-ai-modal-target="sessions"] button'
        assert_selector '[data-ai-modal-target="textarea"]'
        assert_selector "button[aria-label]", minimum: 1
        assert page.evaluate_script(<<~JS)
          Array.from(document.querySelectorAll('#ai_chat_modal [data-ai-modal-target="listView"], #ai_chat_modal [data-ai-modal-target="newSession"], #ai_chat_modal [data-ai-modal-target="sessions"]')).every(element => {
            const box = element.getBoundingClientRect();
            return box.left >= 0 && box.right <= window.innerWidth;
          })
        JS
      end
    end
  ensure
    page.current_window.resize_to(1400, 1000)
  end

  test "account conversations can be created switched and deleted" do
    user = create_user
    alpha = user.chat_sessions.create!(title: "Alpha conversation")
    beta = user.chat_sessions.create!(title: "Beta conversation")
    ChatHistory.create!(user: user, chat_session: alpha, user_message: "Alpha message", bot_response: "Alpha reply")
    ChatHistory.create!(user: user, chat_session: beta, user_message: "Beta message", bot_response: "Beta reply")
    visit new_user_session_path(locale: :en)
    fill_in "Email", with: user.email
    fill_in "Password", with: "secure-password-123"
    click_button "Sign in"
    assert_no_selector "#user_email"
    visit blog_path(locale: :en)
    page.execute_script("document.getElementById('ai_chat_modal').dispatchEvent(new CustomEvent('ai:open'))")
    within "#ai_chat_modal" do
      assert_text "Beta message"
      find('[data-ai-modal-target="back"]').click
      page.save_screenshot("/tmp/ror-chat-conversations.png")
      click_button "Beta conversation"
      assert_text "Beta message"
      page.save_screenshot("/tmp/ror-chat-conversation.png")
      fill_in I18n.t("shared.ai_chat.ask_placeholder", locale: :en), with: "Unsent draft"
      assert_no_text "Alpha message"
      find('[data-ai-modal-target="back"]').click
      click_button "Alpha conversation"
      assert_text "Alpha message"
      assert_no_text "Beta message"
      find('[data-ai-modal-target="back"]').click
      click_button "New chat", exact: true
      assert_selector "[data-history-empty]"
      assert_no_text "Alpha message"
      find('[data-ai-modal-target="back"]').click
      click_button "Beta conversation"
      assert_text "Beta message"
      assert_field I18n.t("shared.ai_chat.ask_placeholder", locale: :en), with: "Unsent draft"
      find('[data-ai-modal-target="back"]').click
      find('[aria-label="Delete chat: Alpha conversation"]').click
    end
    within "dialog[open]" do
      find('[data-confirm-action="ok"]').click
    end
    within "#ai_chat_modal" do
      assert_no_button "Alpha conversation"
      click_button "Beta conversation"
      assert_text "Beta message"
    end
    assert alpha.reload.deleted_at
    visit blog_path(locale: :en)
    page.execute_script("document.getElementById('ai_chat_modal').dispatchEvent(new CustomEvent('ai:open'))")
    within "#ai_chat_modal" do
      assert_text "Beta message"
      find('[data-ai-modal-target="back"]').click
      assert_button "Beta conversation"
      assert_button "New chat"
      assert_no_button "Alpha conversation"
    end
  end
end
