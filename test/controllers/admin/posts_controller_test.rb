require "test_helper"

class Admin::PostsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "admin can rerun ai review for failed post" do
    admin = User.create!(
      name: "Admin",
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      confirmed_at: Time.current,
      role: :admin
    )
    author = User.create!(
      name: "Author",
      email: "author-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      confirmed_at: Time.current,
      role: :author
    )

    post = Post.new(title: "Retry me", status: :published, user: author, verified: false)
    post.body = "Body for moderation"
    post.ai_review_status = :failed
    post.ai_last_error = "socket error"
    post.save!

    sign_in admin

    assert_enqueued_with(job: ModeratePostJob, args: [ post.id ]) do
      post rerun_ai_review_admin_post_path(post, locale: :en)
    end

    assert_redirected_to admin_posts_path(locale: :en)

    post.reload
    assert_equal "pending", post.ai_review_status
    assert_nil post.ai_last_error
  end

  test "admin cannot rerun ai review for in progress post" do
    admin = User.create!(
      name: "Admin",
      email: "admin-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      confirmed_at: Time.current,
      role: :admin
    )
    author = User.create!(
      name: "Author",
      email: "author-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      confirmed_at: Time.current,
      role: :author
    )

    post = Post.new(title: "Busy", status: :published, user: author, verified: false)
    post.body = "Body for moderation"
    post.ai_review_status = :in_progress
    post.save!

    sign_in admin

    assert_no_enqueued_jobs only: ModeratePostJob do
      post rerun_ai_review_admin_post_path(post, locale: :en)
    end

    assert_redirected_to admin_posts_path(locale: :en)

    post.reload
    assert_equal "in_progress", post.ai_review_status
  end
end