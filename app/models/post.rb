class Post < ApplicationRecord
  searchkick word_middle: [ :title, :tags ], callbacks: :async

  belongs_to :user
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_many :post_revisions, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :reactions, as: :reactable, dependent: :destroy
  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings
  enum :status, { draft: 0, published: 1 }
  validates :title, presence: true
  validate :moderation_feedback_consistency
  has_rich_text :body

  scope :verified, -> { where(verified: true) }
  scope :unverified, -> { where(verified: false) }

  def active_revision
    post_revisions.open_for_edit.order(updated_at: :desc).first
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
    !verified? && user == self.user
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

  private

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
