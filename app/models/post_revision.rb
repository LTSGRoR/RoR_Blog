class PostRevision < ApplicationRecord
  belongs_to :post
  belongs_to :author, class_name: "User"
  belongs_to :reviewer, class_name: "User", optional: true

  has_many :post_revision_taggings, dependent: :destroy
  has_many :tags, through: :post_revision_taggings
  has_rich_text :body

  enum :moderation_status, {
    draft: 0,
    pending_review: 1,
    approved: 2,
    rejected: 3
  }

  validates :title, presence: true
  validate :author_owns_post

  scope :current_state, -> { where(moderation_status: [ moderation_statuses[:draft], moderation_statuses[:pending_review] ]) }
  scope :open_for_edit, -> { where(moderation_status: moderation_statuses[:draft]) }
  scope :queue, -> { pending_review.includes(:post, :author).order(submitted_at: :asc, created_at: :asc) }

  def editable_by?(user)
    user.present? && user == author && draft?
  end

  def submit!
    raise ArgumentError, "Title is required" if title.to_s.strip.blank?
    raise ArgumentError, "Body is required" if body.to_plain_text.to_s.strip.blank?

    update!(moderation_status: :pending_review, submitted_at: Time.current)
  end

  def prepare_as_draft!
    return unless pending_review?

    self.moderation_status = :draft
    self.submitted_at = nil
  end

  def approve!(admin:, note: nil)
    Post.transaction do
      post.apply_approved_revision!(revision: self, admin: admin)
      update!(
        moderation_status: :approved,
        reviewer: admin,
        review_note: note.to_s.strip.presence,
        reviewed_at: Time.current
      )
    end
  end

  def reject!(admin:, note: nil)
    cleaned_note = note.to_s.strip
    raise ArgumentError, "Rejection note is required" if cleaned_note.blank?

    update!(
      moderation_status: :rejected,
      reviewer: admin,
      review_note: cleaned_note,
      reviewed_at: Time.current
    )
  end

  def tag_list
    tags.pluck(:name).join(", ")
  end

  private

  def author_owns_post
    return if author == post&.user

    errors.add(:author, "must be the post owner")
  end
end
