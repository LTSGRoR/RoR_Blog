ENV["RAILS_ENV"] ||= "test"
ENV["EMBEDDINGS_AUTO_RUN_ON_BOOT"] = "false"
require_relative "../../config/environment"
require "active_support/test_case"
require "minitest/autorun"
require "minitest/mock"

# Exercise the real restriction methods and comment template without a database.
class AccountContentRenderingTest < ActiveSupport::TestCase
  def owner(banned_at: nil, suspended_until: nil)
    user = User.allocate
    user.define_singleton_method(:banned_at) { banned_at }
    user.define_singleton_method(:suspended_until) { suspended_until }
    user.define_singleton_method(:name) { "Comment author" }
    user.define_singleton_method(:email) { "author@example.com" }
    user.define_singleton_method(:avatar) { Struct.new(:attached?).new(false) }
    user
  end

  def comment_for(user)
    comment = Comment.allocate
    comment.define_singleton_method(:user) { user }
    comment.define_singleton_method(:to_key) { [7] }
    comment.define_singleton_method(:body) { "PRIVATE COMMENT TEXT" }
    comment.define_singleton_method(:created_at) { Time.current }
    comment.define_singleton_method(:post) { nil }
    comment
  end

  def render_comment(comment)
    view = ApplicationController.new.view_context
    original_render = view.method(:render)
    view.define_singleton_method(:render) do |*args, **kwargs|
      if args.first == "comments/replies_frame"
        '<div id="preserved-replies">Other users replies remain</div>'.html_safe
      elsif ["reactions/bar", "comments/reply_form"].include?(args.first)
        "INTERACTION CONTROLS".html_safe
      else
        original_render.call(*args, **kwargs)
      end
    end
    Comment.stub(:new, -> { Comment.allocate }) do
      view.render(partial: "comments/comment", locals: { comment: comment })
    end
  end

  test "banned and suspended comments render a translated placeholder without exposing content" do
    [owner(banned_at: Time.current), owner(suspended_until: 1.day.from_now)].each do |user|
      comment = comment_for(user)
      assert comment.hidden_by_account_restriction?
      %i[en vi ja].each do |locale|
        I18n.with_locale(locale) do
          html = render_comment(comment)
          assert_includes html, I18n.t("comments.account_hidden", raise: true)
          refute_includes html, "PRIVATE COMMENT TEXT"
          refute_includes html, "INTERACTION CONTROLS"
          assert_includes html, "preserved-replies"
        end
      end
    end
  end

  test "expired suspensions and unrestricted accounts render original content" do
    [owner, owner(suspended_until: 1.minute.ago)].each do |user|
      comment = comment_for(user)
      refute comment.hidden_by_account_restriction?
      assert_includes render_comment(comment), "PRIVATE COMMENT TEXT"
    end
  end

  test "banned posts reject public access but allow admin review; suspended posts stay accessible" do
    post = Post.allocate
    post.define_singleton_method(:published?) { true }
    post.define_singleton_method(:verified?) { true }
    user = owner(banned_at: Time.current)
    post.define_singleton_method(:user) { user }
    refute PostPolicy.new(nil, post).show?
    refute post.interactions_enabled?
    assert PostPolicy.new(Struct.new(:admin?).new(true), post).show?
    user = owner(suspended_until: 1.day.from_now)
    assert PostPolicy.new(nil, post).show?
    assert post.interactions_enabled?
    user = owner
    assert PostPolicy.new(nil, post).show?
  end
end
