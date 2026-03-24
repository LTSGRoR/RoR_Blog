class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable
  has_one_attached :avatar

  enum role: { author: 0, admin: 1 }

  validates :name, presence: true

  private

  def company_email_domain
    allowed = ENV.fetch("ALLOWED_EMAIL_DOMAIN", "company.com").downcase
    unless email.to_s.downcase.end_with?("@#{allowed}")
      errors.add(:email, "must be a company email (@#{allowed})")
    end
  end
end
