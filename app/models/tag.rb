class Tag < ApplicationRecord
  searchkick word_start: [ :name ], callbacks: :async

  has_many :taggings, dependent: :destroy
  has_many :posts, through: :taggings
  has_many :post_revision_taggings, dependent: :destroy
  has_many :post_revisions, through: :post_revision_taggings

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  after_commit :reindex_related_posts_async, on: :update, if: :saved_change_to_name?

  def search_data
    { name: name }
  end

  before_save :normalize_name

  private

  def normalize_name
    self.name = name.to_s.strip.downcase
  end

  def reindex_related_posts_async
    posts.distinct.find_each do |post|
      post.reindex(mode: :async)
    end
  end
end
