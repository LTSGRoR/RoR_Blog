require "test_helper"

class ModerationTest < ActiveSupport::TestCase
  setup do
    @admin = create_user(role: :admin)
    @author = create_user
    @post = create_post(user: @author)
  end

  def yield_review_job
    @job.perform_now(@record.id)
  end

  test "unchanged reviewed content is approved" do
    @job, @record = ModeratePostJob, @post
    with_ai_review { }
    assert @post.reload.verified?
    assert @post.ai_review_auto_approved?
  end

  test "editing while a review runs does not approve new content" do
    @job, @record = ModeratePostJob, @post
    with_ai_review { Post.find(@post.id).update!(title: "Changed after review started") }
    assert_not @post.reload.verified?
    assert @post.ai_review_needs_admin_review?
  end

  test "rich text changes invalidate the review" do
    @job, @record = ModeratePostJob, @post
    with_ai_review { Post.find(@post.id).update!(body: "Different content") }
    assert_not @post.reload.verified?
  end

  test "a human rejection is preserved" do
    @job, @record = ModeratePostJob, @post
    with_ai_review { Post.find(@post.id).unverify!(admin: @admin, reason: "Human rejection") }
    assert_not @post.reload.verified?
    assert_equal "Human rejection", @post.unverify_reason
  end

  test "a queued review cannot undo a human rejection before the job starts" do
    @post.unverify!(admin: @admin, reason: "Human rejection")
    @job, @record = ModeratePostJob, @post
    with_ai_review { flunk "Human rejection must not be sent for automatic approval" }
    assert_not @post.reload.verified?
    assert_equal "Human rejection", @post.unverify_reason
  end

  test "a redelivered in-progress review can recover after a worker interruption" do
    @post.mark_ai_in_progress!
    @job, @record = ModeratePostJob, @post
    with_ai_review { }
    assert @post.reload.verified?
  end

  test "a newly queued review is not overwritten by an old result" do
    @job, @record = ModeratePostJob, @post
    with_ai_review { Post.find(@post.id).queue_ai_review! }
    assert_not @post.reload.verified?
    assert @post.ai_review_pending?
  end

  test "withdrawn revision is not applied" do
    @post.update!(verified: true)
    @revision = create_revision(post: @post)
    @job, @record = ModeratePostRevisionJob, @revision
    with_ai_review do
      revision = PostRevision.find(@revision.id)
      revision.prepare_as_draft!
      revision.save!
    end
    assert @revision.reload.draft?
    assert_equal "Original title", @post.reload.title
  end

  test "unchanged pending revision is applied" do
    @post.update!(verified: true)
    @revision = create_revision(post: @post)
    @job, @record = ModeratePostRevisionJob, @revision
    with_ai_review { }
    assert @revision.reload.approved?
    assert_equal "Revision title", @post.reload.title
  end

  test "stale author update cannot overwrite a concurrent moderation result" do
    stale = Post.find(@post.id)
    @post.verify!(@admin)
    assert_raises(ActiveRecord::StaleObjectError) { stale.update!(title: "Stale edit") }
    assert_equal "Original title", @post.reload.title
  end

  test "retryable post failure survives a rolled-back dirty decision" do
    @job, @record = ModeratePostJob, @post
    error = assert_raises(StandardError) do
      with_ai_review(decision: retryable_failure_decision, max_retries: 3) { }
    end
    assert_equal "429 rate limit exceeded", error.message
    assert @post.reload.ai_review_failed?
    assert_equal "429 rate limit exceeded", @post.ai_last_error
    assert_not @post.verified?
  end

  test "retryable revision failure survives a rolled-back dirty decision" do
    @post.update!(verified: true)
    revision = create_revision(post: @post)
    @job, @record = ModeratePostRevisionJob, revision
    error = assert_raises(StandardError) do
      with_ai_review(decision: retryable_failure_decision, max_retries: 3) { }
    end
    assert_equal "429 rate limit exceeded", error.message
    assert revision.reload.ai_review_failed?
    assert_equal "429 rate limit exceeded", revision.ai_last_error
    assert revision.pending_review?
    assert_equal "Original title", @post.reload.title
  end

  test "recovering a dirty record cannot overwrite a superseding review" do
    job = ModeratePostJob.new
    snapshot = job.send(:start_review, @post)
    @post.ai_last_error = "Unpersisted old error"
    Post.find(@post.id).queue_ai_review!

    job.send(:with_current_review, @post, snapshot) do
      flunk "Superseded review must not write failure state"
    end
    assert @post.reload.ai_review_pending?
    assert_nil @post.ai_last_error
  end

  private

  def retryable_failure_decision
    AiModeration::DecisionParser::Decision.new(
      status: :failed, reason: "429 rate limit exceeded",
      payload: { "error_class" => "RubyLLM::RateLimitError" }
    )
  end
end
