class Tag < ApplicationRecord
  searchkick word_start: [:name]

  has_many :taggings, dependent: :destroy
  has_many :posts, through: :taggings

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  def search_data
    { name: name }
  end

  before_save :normalize_name

  private

  def normalize_name
    self.name = name.to_s.strip.downcase
  end
end
