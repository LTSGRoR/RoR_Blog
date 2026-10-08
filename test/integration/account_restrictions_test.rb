require "test_helper"

class AccountRestrictionsTest < ActionDispatch::IntegrationTest
  setup do
    @owner = create_user
    @other = create_user
    @admin = create_user(role: :admin)
    @owned_post = create_post(user: @owner, verified: true)
    @owned_post.update!(title: "Account restriction audit post")
    @host_post = create_post(user: @other, verified: true)
    @parent = @host_post.comments.create!(user: @owner, body: "Restricted author original comment")
    @reply = @host_post.comments.create!(user: @other, parent: @parent, body: "Other author preserved reply")
  end

  def snapshot(name)
    return unless ENV["ACCOUNT_UI_SNAPSHOTS"] == "true"
    directory = Rails.root.join("tmp/account-ui-audit")
    FileUtils.mkdir_p(directory)
    File.write(directory.join("#{name}.html"), response.body)
  end

  test "admin ban hides public posts and comments, unban restores both" do
    sign_in @admin
    post ban_user_path(@owner, locale: :en)
    assert_response :redirect
    assert @owner.reload.banned?
    sign_out @admin

    get blog_path(locale: :en), as: :json
    assert_response :success
    assert_not JSON.parse(response.body).fetch("posts").any? { |item| item["id"] == @owned_post.id }
    get post_path(@owned_post, locale: :en), as: :json
    assert_response :forbidden
    [root_path(locale: :en), team_path(locale: :en), blog_path(locale: :en)].each do |path|
      get path
      assert_response :success
      assert_select "a[href=?]", post_path(@owned_post, locale: :en), count: 0
    end
    get user_path(@owner, locale: :en)
    assert_response :success
    assert_select "a[href=?]", post_path(@owned_post, locale: :en), count: 0
    get post_path(@host_post, locale: :en)
    assert_response :success
    assert_select "#comment_#{@parent.id}" do
      assert_select "p", text: I18n.t("comments.account_hidden")
      assert_select "a[href*='reply']", count: 0
    end
    assert_not_includes response.body, @parent.body
    assert_includes response.body, @reply.body
    snapshot("banned-comments")

    sign_in @admin
    get post_path(@owned_post, locale: :en)
    assert_response :success
    post unban_user_path(@owner, locale: :en)
    assert_response :redirect
    sign_out @admin
    get post_path(@owned_post, locale: :en)
    assert_response :success
    get post_path(@host_post, locale: :en)
    assert_includes response.body, @parent.body
    snapshot("restored-comments")
  end

  test "suspension keeps posts visible, hides comments in every locale, and expiry restores them" do
    sign_in @admin
    post suspend_user_path(@owner, locale: :en), params: {
      suspended_until: 1.day.from_now.iso8601, suspend_time_zone: "UTC"
    }
    assert_response :redirect
    assert @owner.reload.suspended?
    sign_out @admin
    get post_path(@owned_post, locale: :en)
    assert_response :success
    %i[en vi ja].each do |locale|
      get post_path(@host_post, locale: locale)
      assert_response :success
      assert_includes response.body, I18n.t("comments.account_hidden", locale: locale)
      assert_not_includes response.body, @parent.body
      assert_includes response.body, @reply.body
      snapshot("suspended-comments-#{locale}")
    end
    travel 2.days do
      get post_path(@host_post, locale: :en)
      assert_response :success
      assert_includes response.body, @parent.body
    end
    sign_in @admin
    post unsuspend_user_path(@owner, locale: :en)
    assert_response :redirect
    sign_out @admin
    get post_path(@host_post, locale: :en)
    assert_includes response.body, @parent.body
  end

  test "hidden comments reject replies and reactions but existing replies remain reachable" do
    @owner.update!(banned_at: Time.current)
    sign_in @other
    assert_no_difference "Comment.count" do
      post post_comments_path(@host_post, locale: :en), params: {
        comment: { parent_id: @parent.id, body: "Attempt to reply" }
      }, as: :turbo_stream
    end
    assert_response :unprocessable_entity
    assert_includes response.body, I18n.t("comments.restricted_reply")
    assert_no_difference "Reaction.count" do
      post reactions_path(locale: :en), params: {
        reactable_type: "Comment", reactable_id: @parent.id, reaction: { emoji_type: "heart" }
      }, as: :json
    end
    assert_response :forbidden
    get replies_post_comment_path(@host_post, @parent, locale: :en)
    assert_response :success
    assert_includes response.body, @reply.body
  end

  test "ban and suspension invalidate previously signed-in sessions" do
    sign_in @owner
    get mine_posts_path(locale: :en)
    assert_response :success
    @owner.update!(banned_at: Time.current)
    get mine_posts_path(locale: :en)
    assert_response :redirect
    assert_redirected_to new_user_session_path(locale: :en)
    @owner.update!(banned_at: nil, suspended_until: 1.day.from_now)
    sign_in @owner
    get mine_posts_path(locale: :en)
    assert_response :redirect
  end

  test "admin dialogs explain the content consequences" do
    sign_in @admin
    get users_path(locale: :en)
    assert_response :success
    assert_includes response.body, I18n.t("users.admin.modal.ban_message")
    assert_includes response.body, I18n.t("users.admin.modal.suspend_message")
    snapshot("admin-users")
  end

  test "restricted authors reactions disappear from post and comment counts and return after recovery" do
    post_reaction = @owner.reactions.create!(reactable: @host_post, emoji_type: :heart)
    comment_reaction = @owner.reactions.create!(reactable: @reply, emoji_type: :heart)
    assert_counts = lambda do |visible|
      get post_path(@host_post, locale: :en)
      assert_response :success
      ["post_#{@host_post.id}", "comment_#{@reply.id}"].each do |id|
        if visible
          assert_select "#reactions_#{id} span.min-w-8", text: "1", count: 1
        else
          assert_select "#reactions_#{id} span.min-w-8", count: 0
        end
      end
    end
    assert_counts.call(true)
    @owner.update!(banned_at: Time.current)
    assert_counts.call(false)
    @owner.update!(banned_at: nil)
    assert_counts.call(true)
    @owner.update!(suspended_until: 1.day.from_now)
    assert_counts.call(false)
    travel 2.days do
      assert_counts.call(true)
    end
    @owner.update!(suspended_until: nil)
    assert_counts.call(true)
    assert Reaction.exists?(post_reaction.id)
    assert Reaction.exists?(comment_reaction.id)
  end
end
