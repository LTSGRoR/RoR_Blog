require "test_helper"

class ChatSessionsTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user
    sign_in @user
    @first = @user.chat_sessions.create!(title: "First conversation")
    @second = @user.chat_sessions.create!(title: "Second conversation")
  end

  test "sessions persist and messages stay in the selected conversation" do
    first = ChatHistory.create!(user: @user, chat_session: @first, user_message: "First secret")
    ChatHistory.create!(user: @user, chat_session: @second, user_message: "Second secret")
    get chat_sessions_path(locale: :en), as: :json
    assert_response :success
    assert_equal [ @second.id, @first.id ], response.parsed_body["sessions"].map { |session| session["id"] }
    get chat_history_path(locale: :en), params: { chat_session_id: @first.id }, as: :json
    assert_includes response.parsed_body["html"], "First secret"
    assert_not_includes response.parsed_body["html"], "Second secret"
    assert_equal first.id, response.parsed_body["pending"]["id"]
    post chat_sessions_path(locale: :ja), as: :json
    assert_response :created
    session = response.parsed_body
    assert_equal I18n.t("shared.ai_chat.new_chat", locale: :ja), session["title"]
    post chat_path(locale: :en), params: { message: "New topic", chat_session_id: session["id"] }, as: :json
    # The two pending messages still consume the account-wide limit.
    assert_response :too_many_requests
    first.update!(bot_response: "Done")
    post chat_path(locale: :en), params: { message: "New topic", chat_session_id: session["id"] }, as: :json
    assert_response :accepted
    assert_equal session["id"], ChatHistory.find(response.parsed_body["id"]).chat_session_id
    assert_equal "New topic", @user.chat_sessions.find(session["id"]).title
  end

  test "foreign and deleted conversations cannot be read written or deleted" do
    foreign = create_user.chat_sessions.create!
    [ foreign, @first ].each do |session|
      session.update!(deleted_at: Time.current) if session == @first
      get chat_session_path(session, locale: :en), as: :json
      assert_response :not_found
      get chat_history_path(locale: :en), params: { chat_session_id: session.id }, as: :json
      assert_response :not_found
      post chat_path(locale: :en), params: { message: "Attack", chat_session_id: session.id }, as: :json
      assert_response :not_found
      delete chat_session_path(session, locale: :en), as: :json
      assert_response :not_found
    end
  end

  test "deleting a conversation redacts its messages without touching others or resetting quotas" do
    first = ChatHistory.create!(user: @user, chat_session: @first, user_message: "Secret", bot_response: "Answer")
    second = ChatHistory.create!(user: @user, chat_session: @second, user_message: "Keep this", bot_response: "Answer")
    quota = ChatDailyQuota.for_time(Time.current).requests_count
    delete chat_session_path(@first, locale: :en), as: :json
    assert_response :no_content
    assert @first.reload.deleted_at
    assert first.reload.cleared_at
    assert_equal "[cleared]", first.user_message
    assert_nil second.reload.cleared_at
    assert_equal quota, ChatDailyQuota.for_time(Time.current).requests_count
    get chat_sessions_path(locale: :en), as: :json
    assert_equal [ @second.id ], response.parsed_body["sessions"].map { |session| session["id"] }
  end

  test "session lists paginate and older sessions remain directly accessible" do
    21.times { @user.chat_sessions.create! }
    get chat_sessions_path(locale: :en), as: :json
    first = response.parsed_body
    assert_equal 20, first["sessions"].size
    get chat_sessions_path(locale: :en), params: { before: first["before"] }, as: :json
    assert_equal 3, response.parsed_body["sessions"].size
    assert_nil response.parsed_body["before"]
    get chat_session_path(@first, locale: :ja), as: :json
    assert_response :success
    assert_equal @first.id, response.parsed_body["id"]
  end

  test "clearing history affects only the selected conversation" do
    first = ChatHistory.create!(user: @user, chat_session: @first, user_message: "Erase")
    second = ChatHistory.create!(user: @user, chat_session: @second, user_message: "Keep")
    delete chat_history_path(locale: :en), params: { chat_session_id: @first.id }, as: :json
    assert_response :no_content
    assert first.reload.cleared_at
    assert_nil second.reload.cleared_at
  end
end
