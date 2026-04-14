class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable
  has_one_attached :avatar
  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :destroy
  has_many :reactions, dependent: :destroy
  enum :role, { author: 0, admin: 1 }
  validates :name, presence: true

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

  def send_devise_notification(notification, *args)
    devise_mailer.public_send(notification, self, *args).deliver_later
  end
end
