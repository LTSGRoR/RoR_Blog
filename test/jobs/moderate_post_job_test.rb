require "test_helper"

class ModeratePostJobTest < ActiveSupport::TestCase
  test "marks post for admin review when ai returns uncertain" do
    author = User.create!(
      name: "Author",
      email: "author-#{SecureRandom.hex(4)}@example.com",
      password: "password12345",
      password_confirmation: "password12345",
      confirmed_at: Time.current,
      role: :author
    )

    post = Post.new(title: "Test", status: :published, user: author, verified: false)
    post.body = "Body for moderation"
    post.save!

    config = AiModeration::Configuration.current
    decision = AiModeration::DecisionParser::Decision.new(
      status: :needs_admin_review,
      confidence: 0.4,
      risk_score: 0.5,
      reason: "uncertain",
      payload: { "verdict" => "needs_admin_review" }
    )

    fake_client = Struct.new(:decision) do
      def review(instruction:, content_payload:)
        decision
      end
    end.new(decision)

    original_new = AiModeration::Client.method(:new)
    AiModeration::Client.define_singleton_method(:new) { |*args, **kwargs| fake_client }

    ModeratePostJob.perform_now(post.id)
  ensure
    AiModeration::Client.define_singleton_method(:new, original_new)

    post.reload
    assert_includes [ "in_progress", "needs_admin_review" ], post.ai_review_status
    assert_operator post.ai_attempts_count, :>=, 1
  end
end
