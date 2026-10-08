ENV["RAILS_ENV"] ||= "test"
ENV["EMBEDDINGS_AUTO_RUN_ON_BOOT"] = "false"
require_relative "../../config/environment"
require "active_support/test_case"
require "minitest/autorun"

class CommentReplyBroadcastRenderingTest < ActiveSupport::TestCase
  test "actual reply partial renders a generic link without Warden" do
    html = render_reply(restricted: false)
    assert_includes html, "Reply"
    assert_includes html, "/posts/9/comments/7/reply"
  end

  test "restricted parent still renders only its explanation without Warden" do
    html = render_reply(restricted: true)
    assert_includes html, I18n.t("comments.restricted_reply")
    refute_includes html, "/posts/9/comments/7/reply"
  end

  private

  def render_reply(restricted:)
    user = User.allocate
    user.define_singleton_method(:banned_at) { restricted ? Time.current : nil }
    user.define_singleton_method(:suspended_until) { nil }
    parent = Comment.allocate
    parent.define_singleton_method(:user) { user }
    parent.define_singleton_method(:depth) { 0 }
    parent.define_singleton_method(:to_key) { [ 7 ] }
    parent.define_singleton_method(:to_param) { "7" }
    post = Post.allocate
    post.define_singleton_method(:to_param) { "9" }
    ApplicationController.render(partial: "comments/reply_form", locals: {
      post: post, parent_comment: parent, comment: Comment.allocate, open: false
    })
  end
end
