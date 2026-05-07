# Service to orchestrate the feedback suggestion pipeline
class PostRevisionFeedbackService
  # Generate suggestions for a post revision
  # Returns: Hash with suggestions and metadata
  def self.generate_suggestions!(revision)
    return { error: "Suggestions disabled" } unless AIServices[:suggestions_enabled]
    return { error: "Not a rejected revision" } unless revision.rejected?

    service = new(revision)
    service.generate_suggestions
  end

  # Trigger async suggestion generation
  def self.generate_suggestions_async(revision)
    return unless AIServices[:suggestions_enabled]
    return unless revision.rejected?

    # Check if we have a cached version that's still valid
    if revision.suggestions_generated_at.present? && 
       revision.suggestions_generated_at > Time.current - AIServices[:cache_ttl]
      return revision.feedback_suggestions
    end

    # Queue job for async generation
    FeedbackSuggestionGenerationJob.perform_async(revision.id)
  end

  def initialize(revision)
    @revision = revision
  end

  # Main method to generate suggestions
  def generate_suggestions
    # Check if embedding exists
    unless @revision.embedding.present?
      Rails.logger.warn("No embedding for revision #{@revision.id}")
      return { error: "Embedding not available", suggestions: [] }
    end

    # Check cache first
    if cached_suggestions_valid?
      Rails.logger.info("Returning cached suggestions for revision #{@revision.id}")
      return @revision.feedback_suggestions.merge(cached: true)
    end

    # Find similar rejected revisions
    similar_revisions = fetch_similar_revisions
    
    if similar_revisions.blank?
      Rails.logger.info("No similar rejections found for revision #{@revision.id}")
      return { suggestions: [], similar_count: 0 }
    end

    # Generate suggestions
    suggestions = generate_with_agent(similar_revisions)

    # Cache result
    cache_suggestions(suggestions, similar_revisions)

    {
      suggestions: suggestions,
      similar_count: similar_revisions.count,
      cached: false,
      generated_at: Time.current
    }
  rescue => e
    Rails.logger.error("PostRevisionFeedbackService error: #{e.message}")
    { error: e.message, suggestions: [] }
  end

  private

  def cached_suggestions_valid?
    return false unless @revision.suggestions_generated_at.present?
    return false unless @revision.feedback_suggestions.is_a?(Hash)
    
    age = (Time.current - @revision.suggestions_generated_at).to_i
    age < AIServices[:cache_ttl]
  end

  def fetch_similar_revisions
    PostRevision.similar_by_feedback(@revision, limit: 5)
  rescue => e
    Rails.logger.error("Failed to fetch similar revisions: #{e.message}")
    []
  end

  def generate_with_agent(similar_revisions)
    agent = FeedbackSuggestionAgent.new
    agent.generate_suggestions(@revision, similar_revisions)
  rescue => e
    Rails.logger.error("Agent generation failed: #{e.message}")
    []
  end

  def cache_suggestions(suggestions, similar_revisions)
    @revision.update!(
      feedback_suggestions: {
        suggestions: suggestions,
        generated_at: Time.current,
        similar_count: similar_revisions.count,
        model: AIServices[:llm_model]
      },
      suggestions_generated_at: Time.current,
      suggestions_error: false
    )
  rescue => e
    Rails.logger.warn("Failed to cache suggestions: #{e.message}")
  end
end
