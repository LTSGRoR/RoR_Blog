# Job to generate feedback suggestions for post revisions asynchronously
class FeedbackSuggestionGenerationJob
  include Sidekiq::Worker
  sidekiq_options retry: 3

  def perform(post_revision_id)
    return unless AIServices[:suggestions_enabled]

    post_revision = PostRevision.find_by(id: post_revision_id)
    return unless post_revision

    Rails.logger.info("Generating suggestions for PostRevision #{post_revision_id}")

    begin
      # Check if embedding exists (required for similarity search)
      return log_and_cache_error(post_revision, "Embedding not yet generated") if post_revision.embedding.blank?

      # Find similar rejected revisions
      similar_revisions = PostRevision.similar_by_feedback(post_revision, limit: 5)
      
      return log_and_cache_error(post_revision, "No similar rejections found") if similar_revisions.blank?

      # Generate suggestions using agent
      agent = FeedbackSuggestionAgent.new
      suggestions = agent.generate_suggestions(post_revision, similar_revisions)

      # Cache suggestions
      post_revision.update!(
        feedback_suggestions: {
          suggestions: suggestions,
          generated_at: Time.current,
          similar_count: similar_revisions.count,
          model: AIServices[:llm_model]
        },
        suggestions_generated_at: Time.current,
        suggestions_error: false
      )

      Rails.logger.info("Suggestions generated successfully for PostRevision #{post_revision_id}: #{suggestions.count} suggestions")
    rescue => e
      Rails.logger.error("Failed to generate suggestions for PostRevision #{post_revision_id}: #{e.message}")
      log_and_cache_error(post_revision, e.message)
      raise # Sidekiq will retry
    end
  end

  private

  def log_and_cache_error(revision, error_message)
    revision.update(
      feedback_suggestions: {
        error: error_message,
        generated_at: Time.current
      },
      suggestions_error: true
    )
    Rails.logger.warn("Suggestion generation skipped for PostRevision #{revision.id}: #{error_message}")
  end
end
