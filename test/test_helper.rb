ENV["RAILS_ENV"] ||= "test"
ENV["EMBEDDINGS_AUTO_RUN_ON_BOOT"] = "false"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"

Searchkick.disable_callbacks

class ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def create_user(role: :author)
    User.create!(name: "Audit user", email: "#{SecureRandom.uuid}@example.com", password: "secure-password-123", role: role, confirmed_at: Time.current)
  end

  def create_post(user:, verified: false)
    Post.create!(user: user, title: "Original title", body: "Original safe body", status: :published, verified: verified)
  end

  def create_revision(post:, state: :pending_review)
    PostRevision.create!(post: post, author: post.user, title: "Revision title", body: "Revision body", moderation_status: state)
  end

  def with_ai_review(&review)
    config = {
      auto_review_enabled: true, new_post_instruction: "Review", revision_instruction: "Review",
      provider: "mistral", model_name: "test", max_retries: 1
    }
    decision = AiModeration::DecisionParser::Decision.new(status: :auto_approve, confidence: 0.99, risk_score: 0.01, payload: {})
    client = Object.new
    client.define_singleton_method(:review) { |**_arguments| review.call; decision }
    AiModeration::Configuration.stub(:current, config) do
      AiModeration::Client.stub(:new, client) { yield_review_job }
    end
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
