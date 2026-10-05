require "test_helper"

class ChatHistoryPerformanceTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user
    sign_in @user
  end

  test "history is owned, bounded and paginated without duplicate messages" do
    other = ChatHistory.create!(user: create_user, user_message: "Private message")
    messages = 23.times.map { |i| ChatHistory.create!(user: @user, user_message: "Message #{i}") }
    get chat_history_path(locale: :en), as: :json
    assert_response :success
    first = response.parsed_body
    assert_equal 20, first["html"].scan(/id="chat_history_/).size
    assert_not_includes first["html"], "Private message"
    assert_equal messages[3].id, first["before"]
    get chat_history_path(locale: :en), params: { before: first["before"] }, as: :json
    assert_response :success
    assert_equal 3, response.parsed_body["html"].scan(/id="chat_history_/).size
    assert_nil response.parsed_body["before"]
    assert_not_includes response.parsed_body["html"], "chat_history_#{other.id}\""
  end

  test "clearing redacts only own history and preserves quota usage" do
    chat = ChatHistory.create!(user: @user, user_message: "Secret question", bot_response: "Secret answer", provider_meta: { private: "Secret" })
    other = ChatHistory.create!(user: create_user, user_message: "Other user")
    count = ChatDailyQuota.for_time(Time.current).requests_count
    delete chat_history_path(locale: :en), as: :json
    assert_response :no_content
    assert_empty @user.chat_histories.visible
    assert_nil other.reload.cleared_at
    assert_equal "[cleared]", chat.reload.user_message
    assert_nil chat.provider_meta
    assert_equal count, ChatDailyQuota.for_time(Time.current).requests_count
    get chat_status_path(chat, locale: :en), as: :json
    assert_response :not_found
    get chat_history_path(locale: :en), as: :json
    assert_empty response.parsed_body["html"]
    AiGeneration::Service.stub(:new, -> { flunk "Cleared chats must not call providers" }) do
      GeneratePostSuggestionJob.perform_now(chat.id)
    end
  end

  test "pending status does not render message HTML" do
    chat = ChatHistory.create!(user: @user, user_message: "Pending")
    get chat_status_path(chat, locale: :en), as: :json
    assert_response :success
    assert_equal false, response.parsed_body["ready"]
    assert_not response.parsed_body.key?("html")
    chat.update!(bot_response: "Done")
    get chat_status_path(chat, locale: :en), as: :json
    assert_equal true, response.parsed_body["ready"]
    assert_includes response.parsed_body["html"], "Done"
  end
end
