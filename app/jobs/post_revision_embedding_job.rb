# Job to generate embeddings for post revisions asynchronously
class PostRevisionEmbeddingJob
  include Sidekiq::Worker
  sidekiq_options retry: 5

  def perform(post_revision_id)
    return unless AIServices[:embeddings_enabled]

    post_revision = PostRevision.find_by(id: post_revision_id)
    return unless post_revision

    # Skip if embedding already generated
    return if post_revision.embedding_generated_at.present?

    # Skip if revision is not rejected (we only embed rejected for feedback patterns)
    return unless post_revision.rejected?

    Rails.logger.info("Generating embedding for PostRevision #{post_revision_id}")

    begin
      # Prepare text for embedding: title + body excerpt
      text_to_embed = prepare_embedding_text(post_revision)
      
      # Generate embedding
      embedding_service = EmbeddingService.instance
      embedding = embedding_service.generate_embedding(text_to_embed)
      
      # Save embedding
      post_revision.update!(
        embedding: embedding,
        embedding_generated_at: Time.current,
        suggestions_error: false
      )
      
      Rails.logger.info("Embedding generated successfully for PostRevision #{post_revision_id}")
    rescue => e
      Rails.logger.error("Failed to generate embedding for PostRevision #{post_revision_id}: #{e.message}")
      post_revision.update(suggestions_error: true)
      raise # Sidekiq will retry
    end
  end

  private

  def prepare_embedding_text(revision)
    title = revision.title.to_s
    body = revision.body.to_plain_text[0..500] # First 500 chars of body
    tags = revision.tags.pluck(:name).join(', ')
    
    "Title: #{title}\n\nContent: #{body}\n\nTags: #{tags}"
  end
end
