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

  # Callbacks for AI features
  after_commit :queue_embedding_job, on: :update, if: :just_rejected?

  scope :current_state, -> { where(moderation_status: [ moderation_statuses[:draft], moderation_statuses[:pending_review] ]) }
  scope :open_for_edit, -> { where(moderation_status: moderation_statuses[:draft]) }
  scope :queue, -> { pending_review.includes(:post, :author).order(submitted_at: :asc, created_at: :asc) }
  
  # Find similar rejected revisions by vector similarity
  scope :similar_by_feedback, ->(revision, limit: 5) {
    return none if revision.embedding.blank?
    
    where(moderation_status: moderation_statuses[:rejected])
      .where("review_note IS NOT NULL")
      .where.not(id: revision.id)
      .select("*, embedding <=> ? as similarity", revision.embedding)
      .order("similarity ASC")
      .limit(limit)
  }

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

  def just_rejected?
    moderation_status == 'rejected' && saved_change_to_moderation_status?
  end

  def queue_embedding_job
    return unless AIServices[:embeddings_enabled]
    
    PostRevisionEmbeddingJob.perform_async(id)
  end
end