class CreatePosts < ActiveRecord::Migration[8.0]
  def change
    create_table :posts do |t|
      t.string :title, null: false
      t.text :body
      t.integer :status, null: false, default: 0
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    add_index :posts, :status
  end
end
