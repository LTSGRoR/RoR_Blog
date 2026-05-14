class Tagging < ApplicationRecord
  belongs_to :post, touch: true
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :post_id }

  after_commit :reindex_post_search_document_async

  private

  def reindex_post_search_document_async
    PostSearchIndexJob.perform_later(post_id)
  rescue StandardError => e
    Rails.logger.warn("Failed to reindex Post##{post_id} after tagging change: #{e.class} - #{e.message}")
  end
end
