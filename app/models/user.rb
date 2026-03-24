class User < ApplicationRecord
  has_secure_password
  has_one_attached :avatar

  enum role: { author: 0, admin: 1 }

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  validate :company_email_domain

  private

  def company_email_domain
    allowed = ENV.fetch("ALLOWED_EMAIL_DOMAIN", "company.com").downcase
    unless email.to_s.downcase.end_with?("@#{allowed}")
      errors.add(:email, "must be a company email (@#{allowed})")
    end
  end
end
