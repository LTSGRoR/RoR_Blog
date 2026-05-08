class CreatePostRevisionTaggings < ActiveRecord::Migration[8.0]
  def change
    create_table :post_revision_taggings do |t|
      t.references :post_revision, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end

    add_index :post_revision_taggings, %i[post_revision_id tag_id], unique: true
  end
end
