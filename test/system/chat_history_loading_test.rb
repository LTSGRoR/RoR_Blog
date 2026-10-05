require "application_system_test_case"

class ChatHistoryLoadingTest < ApplicationSystemTestCase
  test "closed modal stays empty and opening loads paginated history" do
    user = create_user
    23.times { |i| ChatHistory.create!(user: user, user_message: "History message #{i}", bot_response: "Complete") }
    visit new_user_session_path(locale: :en)
    fill_in "Email", with: user.email
    fill_in "Password", with: "secure-password-123"
    click_button "Sign in"
    assert_no_selector "#user_email"
    visit blog_path(locale: :en)
    assert_no_selector '#ai_chat_modal [id^="chat_history_"]', visible: :all
    page.execute_script("document.getElementById('ai_chat_modal').dispatchEvent(new CustomEvent('ai:open'))")
    within "#ai_chat_modal" do
      assert_text "History message 22"
      assert_no_text /History message 0\b/
      click_button "Load older messages"
      assert_text /History message 0\b/
      assert_no_button "Load older messages"
    end
    assert_selector '#ai_chat_modal [id^="chat_history_"]', count: 23
    within "#ai_chat_modal" do
      assert_no_button "Clear history"
    end
  end
end
