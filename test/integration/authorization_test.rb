require "test_helper"

class AuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_user
    @other = create_user
    @post = create_post(user: @owner, verified: true)
  end

  test "create endpoint cannot edit a pending revision" do
    revision = create_revision(post: @post)
    sign_in @owner
    post post_revision_path(@post, locale: :en), params: { post_revision: { title: "Bypass", body: "Changed" } }, as: :json
    assert_response :forbidden
    assert_equal "Revision title", revision.reload.title
    assert revision.pending_review?
  end

  test "another author cannot read an unverified post" do
    @post.update!(verified: false)
    sign_in @other
    get post_path(@post, locale: :en), as: :json
    assert_response :forbidden
  end

  test "chat cannot use another author's private post" do
    @post.update!(verified: false)
    sign_in @other
    assert_no_enqueued_jobs only: GeneratePostSuggestionJob do
      post chat_post_path(@post, locale: :en), params: { message: "Read this" }, as: :json
    end
    assert_response :forbidden
  end

  test "chat cannot expose another user's history" do
    chat = ChatHistory.create!(user: @owner, user_message: "Private question")
    sign_in @other
    get chat_status_path(chat, locale: :en), as: :json
    assert_response :not_found
  end

  test "chat returns a retryable limit response" do
    sign_in @owner
    ChatHistory::USER_PENDING_LIMIT.times { ChatHistory.create!(user: @owner, user_message: "Waiting") }
    post chat_path(locale: :en), params: { message: "More" }, as: :json
    assert_response :too_many_requests
    assert_equal "600", response.headers["Retry-After"]
  end

  test "a stale form cannot overwrite another saved edit" do
    @post.update!(verified: false)
    old_version = @post.lock_version
    @post.update!(title: "Newer saved title")
    sign_in @owner
    patch post_path(@post, locale: :en), params: { post: { title: "Old form title", lock_version: old_version } }, as: :json
    assert_response :conflict
    assert_equal "Newer saved title", @post.reload.title
  end

  test "a new revision can be saved and submitted through the author form" do
    sign_in @owner
    AiModeration::Configuration.stub(:current, { auto_review_enabled: false }) do
      post post_revision_path(@post, locale: :en), params: {
        post_revision: { title: "New revision", body: "Valid revision body" }, commit_action: "submit_for_review"
      }
    end
    assert_response :redirect
    assert @post.post_revisions.last.pending_review?
  end

  test "reply pagination cannot be expanded by request depth" do
    root = @post.comments.create!(user: @owner, body: "Root")
    12.times { |i| @post.comments.create!(user: @owner, parent: root, body: "Reply #{i}") }
    sign_in @other
    get replies_post_comment_path(@post, root, locale: :en), params: { depth: 1_000, visible_depth_limit: 1_000 }
    assert_response :success
    assert_select "article", count: Comment::REPLY_PAGE_SIZE
    assert_select "a", text: "Next replies"
    get replies_post_comment_path(@post, root, locale: :en), params: { replies_page: 2 }
    assert_response :success
    assert_select "article", count: 2
  end
end
