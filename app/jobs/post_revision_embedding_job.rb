require Rails.root.join("lib/services/embedding_service")

class PostRevisionEmbeddingJob
  include Sidekiq::Worker
  sidekiq_options retry: 5

  def perform(post_revision_id)
    return unless AIServices[:embeddings_enabled]

    post_revision = PostRevision.find_by(id: post_revision_id)
    return unless post_revision
    return if post_revision.embedding_generated_at.present?
    return unless post_revision.rejected?

    Rails.logger.info("Generating embedding for PostRevision #{post_revision_id}")

    begin
      text_to_embed = prepare_embedding_text(post_revision)
      embedding_service = EmbeddingService.instance
      embedding = embedding_service.generate_embedding(text_to_embed)
      post_revision.update!(
        embedding: Pgvector.encode(embedding),
        embedding_generated_at: Time.current,
        suggestions_error: false
      )
      
      Rails.logger.info("Embedding generated successfully for PostRevision #{post_revision_id}")
    rescue => e
      Rails.logger.error("Failed to generate embedding for PostRevision #{post_revision_id}: #{e.message}")
      post_revision.update(suggestions_error: true)
      raise
    end
  end

  private

  def prepare_embedding_text(revision)
    title = revision.title.to_s
    body = revision.body.to_plain_text[0..500]
    tags = revision.tags.pluck(:name).join(', ')
    
    "Title: #{title}\n\nContent: #{body}\n\nTags: #{tags}"
  end
end
