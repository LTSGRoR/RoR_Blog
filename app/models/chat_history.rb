class ChatHistory < ApplicationRecord
  belongs_to :user
  belongs_to :post, optional: true

  validates :user_message, presence: true
  # `bot_response` is filled asynchronously by a background job, so we allow
  # records to be created without it and validate presence only on update if needed.

  scope :for_user, ->(user_id) { where(user_id: user_id) }

  def suggested_post_ids
    ids = provider_meta_hash[:suggested_post_ids] || provider_meta_hash["suggested_post_ids"]
    Array(ids).filter_map { |value| Integer(value, exception: false) }.uniq
  end

  def suggested_posts(limit: 3)
    ids = suggested_post_ids.first(limit)
    return [] if ids.empty?

    posts_by_id = Post.where(id: ids, status: Post.statuses[:published], verified: true)
                      .includes(:user, :tags)
                      .index_by(&:id)

    ids.filter_map { |id| posts_by_id[id] }
  end

  private

  def provider_meta_hash
    provider_meta.is_a?(Hash) ? provider_meta : {}
  end
end
