class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable
  has_one_attached :avatar
  has_many :posts, dependent: :destroy
  has_many :post_revisions, foreign_key: :author_id, dependent: :destroy
  has_many :reviewed_post_revisions, class_name: "PostRevision", foreign_key: :reviewer_id, dependent: :nullify
  has_many :comments, dependent: :destroy
  has_many :reactions, dependent: :destroy
  enum :role, { author: 0, admin: 1 }
  validates :name, presence: true
  validates :profile_title, length: { maximum: 120 }, allow_blank: true
  validates :bio, length: { maximum: 600 }, allow_blank: true
  validate :not_banned_and_suspended

  # Scopes for admin user management
  scope :by_name, ->(q) {
    return all if q.blank?
    where("users.name ILIKE :q OR users.email ILIKE :q", q: "%#{q}%")
  }

  scope :by_role, ->(r) {
    return all if r.blank?
    where(role: r)
  }

  scope :by_status, ->(s) {
    return all if s.blank?
    case s.to_s
    when "banned"
      where.not(banned_at: nil)
    when "suspended"
      where(banned_at: nil).where(suspended_until: Time.current..)
    when "active"
      where(banned_at: nil).where(suspended_until: [ nil, ..Time.current ])
    else
      all
    end
  }

  def banned?
    banned_at.present?
  end

  def suspended?
    suspended_until.present? && suspended_until.future?
  end

  def active_for_authentication?
    super && !banned? && !suspended?
  end

  def inactive_message
    return :banned if banned?
    return :suspended if suspended?

    super
  end

  protected

  def not_banned_and_suspended
    return unless banned_at.present? && suspended?

    errors.add(:base, "User cannot be banned and suspended at the same time")
  end

  def send_devise_notification(notification, *args)
    devise_mailer.public_send(notification, self, *args).deliver_later
  end
end
