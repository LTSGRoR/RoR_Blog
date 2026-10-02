require "test_helper"

class EmbeddingPerformanceTest < ActiveSupport::TestCase
  test "embedding writes do not schedule followups and unchanged jobs do not call the provider" do
    post = create_post(user: create_user, verified: true)
    calls = 0
    service = Object.new
    service.define_singleton_method(:embed) { |**| calls += 1; Array.new(1536, 0.1) }
    clear_enqueued_jobs
    AiGeneration::Service.stub(:new, service) do
      assert_no_enqueued_jobs only: IndexPostEmbeddingsJob do
        IndexPostEmbeddingsJob.perform_now(post.id)
        IndexPostEmbeddingsJob.perform_now(post.id)
      end
    end
    assert_equal 1, calls
    assert post.reload.embedding.present?
    assert_no_enqueued_jobs only: IndexPostEmbeddingsJob do
      post.update!(ai_last_error: "Metadata only")
    end
    assert_enqueued_jobs 1, only: IndexPostEmbeddingsJob do
      post.update!(body: "New source content")
    end
  end
end
