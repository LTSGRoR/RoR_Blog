class CreateReactions < ActiveRecord::Migration[8.0]
  def change
    create_table :reactions do |t|
      t.references :user, null: false, foreign_key: true
      t.references :reactable, polymorphic: true, null: false
      t.string :emoji_type, null: false

      t.timestamps
    end

    add_index :reactions,
              [:user_id, :reactable_type, :reactable_id, :emoji_type],
              unique: true,
              name: "index_reactions_unique_per_user_target_emoji"
  end
end
