class Tag < ApplicationRecord
  has_many :taggings, dependent: :destroy
  has_many :posts, through: :taggings

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  before_save :normalize_name

  private

  def normalize_name
    self.name = name.to_s.strip.downcase
  end
end
