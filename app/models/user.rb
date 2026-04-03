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
  validates :email, format: {
    with: /\A[^@]+@department\.com\z/i,
    message: "must be a @department.com address"
  }
end
