class ChatHistory < ApplicationRecord
  belongs_to :user
  belongs_to :post, optional: true

  validates :user_message, presence: true

  scope :for_user, ->(user_id) { where(user_id: user_id) }

  def embedding_text
    parts = []
    parts << "User: #{user_message.to_s.strip}" if user_message.present?
    parts << "Assistant: #{bot_response.to_s.strip}" if bot_response.present?
    parts.join("\n\n")
  end

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
