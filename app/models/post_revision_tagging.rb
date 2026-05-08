class PostRevisionTagging < ApplicationRecord
  belongs_to :post_revision, touch: true
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :post_revision_id }
end
