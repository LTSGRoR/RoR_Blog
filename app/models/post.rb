class Post < ApplicationRecord
  belongs_to :user

  enum :status, { draft: 0, published: 1 }

  validates :title, presence: true
  has_rich_text :body
end
