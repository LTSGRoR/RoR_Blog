class Post < ApplicationRecord
  searchkick word_middle: [ :title, :tags ], callbacks: false
  after_create_commit :enqueue_search_index
  after_update_commit :enqueue_search_index, if: :search_index_reindex_needed?
  after_update_commit :broadcast_ai_review_updates, if: :ai_review_realtime_update?

  belongs_to :user
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_many :post_revisions, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :reactions, as: :reactable, dependent: :destroy
  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings
  enum :status, { draft: 0, published: 1 }
  enum :ai_review_status, {
    pending: 0,
    in_progress: 1,
    auto_approved: 2,
    needs_admin_review: 3,
    failed: 4
  }, prefix: :ai_review
  validates :title, presence: true
  validate :moderation_feedback_consistency
  has_rich_text :body

  scope :verified, -> { where(verified: true) }
  scope :unverified, -> { where(verified: false) }

  def tag_ids=(value)
    mark_removed_tags_for_search_index(value)
    super
  end

  def active_revision
    post_revisions.current_state.order(updated_at: :desc).first
  end

  def apply_approved_revision!(revision:, admin:)
    raise ArgumentError, "Revision does not belong to this post" unless revision.post_id == id

    self.title = revision.title
    self.body = revision.body.to_s
    self.tag_ids = revision.tags.pluck(:id)
    verify!(admin)
  end

  def verify!(admin)
    raise "Cannot verify draft posts" unless published?

    update!(
      verified: true,
      verified_at: Time.current,
      verified_by_id: admin.id,
      unverify_reason: nil,
      author_feedback_reply: nil,
      author_replied_at: nil,
      reviewed_at: Time.current,
      reviewed_by: admin
    )
  end

  def unverify!(admin:, reason:)
    raise "Cannot leave feedback for draft posts" unless published?

    cleaned_reason = reason.to_s.strip
    raise ArgumentError, "Unverify reason is required" if cleaned_reason.blank?

    update!(
      verified: false,
      verified_at: nil,
      verified_by_id: nil,
      unverify_reason: cleaned_reason,
      author_feedback_reply: nil,
      author_replied_at: nil,
      reviewed_at: Time.current,
      reviewed_by: admin
    )
  end

  def reply_to_feedback!(author:, reply:)
    raise "No admin feedback to reply to" if unverify_reason.blank?
    raise "Only the post author can reply" unless author == user

    cleaned_reply = reply.to_s.strip
    raise ArgumentError, "Reply is required" if cleaned_reply.blank?

    update!(
      author_feedback_reply: cleaned_reply,
      author_replied_at: Time.current
    )
  end

  def feedback_visible_to?(user)
    user.present? && (user == self.user || user.admin?)
  end

  def interactions_enabled?
    published? && verified?
  end

  def editable_by?(user)
    return false if user&.admin?
    user == self.user && (draft? || !verified?)
  end

  def search_data
    {
      title: title,
      body: body.to_plain_text,
      tags: tags.map(&:name),
      status: self[:status],
      verified: verified,
      user_id: user_id
    }
  end

  def tag_list
    tags.pluck(:name).join(", ")
  end

  def queue_ai_review!
    update!(
      ai_review_status: :pending,
      ai_attempts_count: 0,
      ai_last_error: nil,
      ai_decision_payload: {},
      ai_confidence: nil,
      ai_risk_score: nil,
      ai_provider: nil,
      ai_model_name: nil,
      ai_reviewed_at: nil
    )
  end

  def mark_ai_in_progress!
    update!(
      ai_review_status: :in_progress,
      ai_attempts_count: ai_attempts_count + 1,
      ai_last_error: nil
    )
  end

  def record_ai_decision!(decision:, config:)
    update!(
      ai_confidence: decision.confidence,
      ai_risk_score: decision.risk_score,
      ai_provider: config.fetch(:provider),
      ai_model_name: config.fetch(:model_name),
      ai_decision_payload: decision.payload,
      ai_reviewed_at: Time.current
    )
  end

  def mark_ai_auto_approved!
    update!(ai_review_status: :auto_approved, ai_last_error: nil)
  end

  def mark_ai_needs_admin_review!(reason:)
    update!(ai_review_status: :needs_admin_review, ai_last_error: reason.to_s.presence)
  end

  def mark_ai_failed!(reason:)
    update!(ai_review_status: :failed, ai_last_error: reason.to_s)
  end

  private

  def enqueue_search_index
    PostSearchIndexJob.perform_later(id)
    @removed_tags_for_search_index = false
  end

  def search_index_reindex_needed?
    search_index_data_changed? || @removed_tags_for_search_index
  end

  def search_index_data_changed?
    saved_change_to_title? ||
      saved_change_to_status? ||
      saved_change_to_verified? ||
      saved_change_to_user_id?
  end

  def mark_removed_tags_for_search_index(value)
    return unless persisted?

    next_tag_ids = Array(value).reject(&:blank?).map(&:to_i).uniq
    current_tag_ids = taggings.pluck(:tag_id)
    @removed_tags_for_search_index = (current_tag_ids - next_tag_ids).any?
  end

  def ai_review_realtime_update?
    saved_change_to_ai_review_status? ||
      saved_change_to_ai_last_error? ||
      saved_change_to_ai_confidence? ||
      saved_change_to_ai_risk_score? ||
      saved_change_to_ai_reviewed_at? ||
      saved_change_to_ai_model_name? ||
      saved_change_to_ai_provider? ||
      saved_change_to_verified?
  end

  def broadcast_ai_review_updates
    Turbo::StreamsChannel.broadcast_replace_later_to(
      self,
      target: ActionView::RecordIdentifier.dom_id(self, :ai_review_panel),
      partial: "posts/ai_review_panel",
      locals: { post: self }
    )

    Turbo::StreamsChannel.broadcast_replace_later_to(
      "posts_mine_user_#{user_id}",
      target: ActionView::RecordIdentifier.dom_id(self, :mine_visibility),
      partial: "posts/mine_visibility_cell",
      locals: { post: self }
    )

    Turbo::StreamsChannel.broadcast_replace_later_to(
      "posts_mine_user_#{user_id}",
      target: ActionView::RecordIdentifier.dom_id(self, :mine_updated),
      partial: "posts/mine_updated_cell",
      locals: { post: self }
    )

    Turbo::StreamsChannel.broadcast_replace_later_to(
      "admin_posts",
      target: ActionView::RecordIdentifier.dom_id(self, :admin_status),
      partial: "admin/posts/post_status_cell",
      locals: { post: self }
    )

    Turbo::StreamsChannel.broadcast_replace_later_to(
      "admin_posts",
      target: ActionView::RecordIdentifier.dom_id(self, :admin_ai_review),
      partial: "admin/posts/post_ai_review_cell",
      locals: { post: self }
    )

    Turbo::StreamsChannel.broadcast_replace_later_to(
      "admin_posts",
      target: ActionView::RecordIdentifier.dom_id(self, :admin_submitted),
      partial: "admin/posts/post_submitted_cell",
      locals: { post: self }
    )

    Turbo::StreamsChannel.broadcast_replace_later_to(
      "admin_posts",
      target: ActionView::RecordIdentifier.dom_id(self, :admin_ai_assessment),
      partial: "admin/posts/post_ai_assessment_section",
      locals: { post: self }
    )
  end

  def moderation_feedback_consistency
    if published? && reviewed_at.present? && !verified? && unverify_reason.blank?
      errors.add(:unverify_reason, "can't be blank after admin feedback")
    end

    if verified? && unverify_reason.present?
      errors.add(:unverify_reason, "must be blank when the post is verified")
    end

    if reviewed_at.present? ^ reviewed_by_id.present?
      errors.add(:base, "review metadata is incomplete")
    end

    if unverify_reason.blank? && author_feedback_reply.present?
      errors.add(:author_feedback_reply, "must be blank when there is no admin feedback")
    end

    if author_replied_at.present? && author_feedback_reply.blank?
      errors.add(:author_feedback_reply, "can't be blank when reply timestamp is set")
    end
  end
end
