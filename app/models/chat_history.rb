class ChatHistory < ApplicationRecord
  belongs_to :user
  belongs_to :post, optional: true

  MAX_MESSAGE_LENGTH = 4_000
  REQUEST_TTL = 10.minutes
  USER_HOURLY_LIMIT = ENV.fetch("AI_CHAT_USER_HOURLY_LIMIT", "20").to_i
  USER_PENDING_LIMIT = ENV.fetch("AI_CHAT_USER_PENDING_LIMIT", "2").to_i
  DAILY_LIMIT = ENV.fetch("AI_CHAT_DAILY_LIMIT", "500").to_i
  class QuotaExceeded < StandardError; end

  before_create :prepare_daily_quota
  after_create :count_daily_request

  validates :user_message, presence: true, length: { maximum: MAX_MESSAGE_LENGTH }

  # Reserve capacity in PostgreSQL so limits hold across web processes, even
  # when the cache is unavailable. Count accepted requests, including failures.
  def self.accept_request!(user:, post:, message:)
    transaction do
      # Only this user's acceptance checks need serialization.
      connection.execute("SELECT pg_advisory_xact_lock(741902002, #{Integer(user.id)})")
      now = Time.current
      history = where(user_id: user.id)
      if history.where(created_at: (now - 1.hour)..).count >= USER_HOURLY_LIMIT ||
          history.where(bot_response: nil, created_at: (now - REQUEST_TTL)..).count >= USER_PENDING_LIMIT
        raise QuotaExceeded, "Assistant request limit reached. Please try again later."
      end

      quota = ChatDailyQuota.for_time(now)
      quota.with_lock do
        raise QuotaExceeded, "Assistant request limit reached. Please try again later." if quota.requests_count >= DAILY_LIMIT
        create!(user: user, post: post, user_message: message, created_at: now)
      end
    end
  end

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

  def self.suggestion_map(histories)
    ids = histories.flat_map { |history| history.suggested_post_ids.first(3) }.uniq
    Post.where(id: ids, status: Post.statuses[:published], verified: true)
        .includes(:user, :tags, :rich_text_body, thumbnail_attachment: :blob).index_by(&:id)
  end

  def suggested_posts(limit: 3)
    ids = suggested_post_ids.first(limit)
    return [] if ids.empty?

    posts_by_id = Post.where(id: ids, status: Post.statuses[:published], verified: true)
                      .includes(:user, :tags, :rich_text_body, thumbnail_attachment: :blob)
                      .index_by(&:id)

    ids.filter_map { |id| posts_by_id[id] }
  end

  private

  def prepare_daily_quota
    @daily_quota = ChatDailyQuota.for_time(created_at || Time.current)
  end

  def count_daily_request
    @daily_quota.increment!(:requests_count)
  end

  def provider_meta_hash
    provider_meta.is_a?(Hash) ? provider_meta : {}
  end
end
