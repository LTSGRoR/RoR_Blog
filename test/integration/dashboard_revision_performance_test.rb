require "test_helper"

class DashboardRevisionPerformanceTest < ActionDispatch::IntegrationTest
  test "dashboard loads only latest active revisions instead of revision history" do
    user = create_user
    post = create_post(user: user, verified: true)
    12.times { create_revision(post: post, state: :rejected) }
    older = create_revision(post: post, state: :draft)
    latest = create_revision(post: post, state: :pending_review)
    older.update_columns(updated_at: 1.day.ago)
    latest.update_columns(updated_at: Time.current)
    sign_in user
    loaded = 0
    capture = ->(_name, _start, _finish, _id, payload) do
      loaded += payload[:record_count] if payload[:class_name] == "PostRevision"
    end
    ActiveSupport::Notifications.subscribed(capture, "instantiation.active_record") do
      get mine_posts_path(locale: :en)
    end
    assert_response :success
    assert_equal 1, loaded
  end
end
