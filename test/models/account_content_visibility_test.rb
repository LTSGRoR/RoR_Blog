require "test_helper"

class AccountContentVisibilityTest < ActiveSupport::TestCase
  test "ban and unban hide and restore posts without changing verification" do
    owner = create_user
    post = create_post(user: owner, verified: true)
    unverified_post = create_post(user: owner)
    comment = post.comments.create!(user: owner, body: "Existing comment")
    admin = create_user(role: :admin)

    owner.update!(banned_at: Time.current)
    assert_empty Post.publicly_visible.where(id: post.id)
    assert_not PostPolicy.new(nil, post.reload).show?
    assert PostPolicy.new(admin, post).show?
    assert_not post.interactions_enabled?
    assert comment.reload.hidden_by_account_restriction?

    owner.update!(banned_at: nil)
    assert_equal [ post.id ], Post.publicly_visible.where(id: post.id).pluck(:id)
    assert PostPolicy.new(nil, post.reload).show?
    assert post.verified?
    assert_empty Post.publicly_visible.where(id: unverified_post.id)
    assert_not comment.reload.hidden_by_account_restriction?
  end

  test "suspension hides comments while posts remain public and expiry restores comments" do
    owner = create_user
    post = create_post(user: owner, verified: true)
    comment = post.comments.create!(user: owner, body: "Existing comment")
    owner.update!(suspended_until: 1.day.from_now)

    assert_equal [ post.id ], Post.publicly_visible.where(id: post.id).pluck(:id)
    assert PostPolicy.new(nil, post.reload).show?
    assert post.interactions_enabled?
    assert comment.reload.hidden_by_account_restriction?
    travel 2.days do
      assert_not comment.reload.hidden_by_account_restriction?
    end
  end

  test "hidden parents preserve existing replies but reject new replies" do
    owner = create_user
    other = create_user
    post = create_post(user: other, verified: true)
    parent = post.comments.create!(user: owner, body: "Restricted parent")
    reply = post.comments.create!(user: other, parent: parent, body: "Legitimate reply")
    owner.update!(banned_at: Time.current)

    assert_equal [ reply.id ], parent.replies.pluck(:id)
    assert_not reply.reload.hidden_by_account_restriction?
    assert_not post.comments.build(user: other, parent: parent.reload, body: "New reply").valid?
  end

  test "search excludes banned owners even when Elasticsearch returns stale hits" do
    owner = create_user
    post = create_post(user: owner, verified: true)
    hits = [ post ]
    hits.define_singleton_method(:total_count) { 1 }
    owner.update!(banned_at: Time.current)

    Post.stub(:search, lambda { |_query, **options|
      assert_includes options[:where][:user_id][:not], owner.id
      hits
    }) do
      assert_empty PublicPostSearch.new(query: "test", scope: Post.all).results
    end
  end

  test "previously saved recommendations hide banned posts and restore them after unban" do
    owner = create_user
    post = create_post(user: owner, verified: true)
    chat = ChatHistory.create!(user: create_user, user_message: "Recommendations", provider_meta: { suggested_post_ids: [ post.id ] })
    assert_equal [ post.id ], chat.suggested_posts.map(&:id)
    owner.update!(banned_at: Time.current)
    assert_empty chat.suggested_posts
    assert_empty ChatHistory.suggestion_map([ chat ])
    owner.update!(banned_at: nil)
    assert_equal [ post.id ], chat.suggested_posts.map(&:id)
  end
end
