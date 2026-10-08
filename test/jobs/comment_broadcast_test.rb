require "test_helper"

class CommentBroadcastTest < ActiveSupport::TestCase
  include ActionCable::TestHelper

  setup do
    @post = create_post(user: create_user, verified: true)
    @parent = @post.comments.create!(user: @post.user, body: "Parent comment")
    @reply = @post.comments.create!(user: create_user, parent: @parent, body: "Nested reply")
  end

  test "nested reply broadcast renders without a browser Warden session" do
    assert_broadcasts @post.to_gid_param, 1 do
      Turbo::Streams::ActionBroadcastJob.perform_now(
        @post.to_gid_param, action: :replace, target: "replies_comment_#{@parent.id}",
        partial: "comments/replies_frame",
        locals: { comment: @parent, current_depth: 0, visible_depth_limit: 1 }
      )
    end
    html = ApplicationController.render(partial: "comments/replies_frame", locals: {
      comment: @parent, current_depth: 0, visible_depth_limit: 1
    })
    assert_includes html, @reply.body
    assert_includes html, "Reply"
  end

  test "top level comment broadcast also renders without Warden" do
    assert_broadcasts @post.to_gid_param, 1 do
      Turbo::Streams::ActionBroadcastJob.perform_now(
        @post.to_gid_param, action: :append, target: "comments_post_#{@post.id}",
        partial: "comments/comment",
        locals: { comment: @parent, current_depth: 0, visible_depth_limit: 1 }
      )
    end
  end
end
