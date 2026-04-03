class EnforceSingleReactionPerUserTarget < ActiveRecord::Migration[8.0]
  def up
    # Keep the newest reaction when a user has multiple reactions on the same target.
    execute <<~SQL
      DELETE FROM reactions
      WHERE id IN (
        SELECT id FROM (
          SELECT id,
                 ROW_NUMBER() OVER (
                   PARTITION BY user_id, reactable_type, reactable_id
                   ORDER BY updated_at DESC, id DESC
                 ) AS row_num
          FROM reactions
        ) dedup
        WHERE dedup.row_num > 1
      )
    SQL

    remove_index :reactions, name: "index_reactions_unique_per_user_target_emoji"
    add_index :reactions,
              [ :user_id, :reactable_type, :reactable_id ],
              unique: true,
              name: "index_reactions_unique_per_user_target"
  end

  def down
    remove_index :reactions, name: "index_reactions_unique_per_user_target"
    add_index :reactions,
              [ :user_id, :reactable_type, :reactable_id, :emoji_type ],
              unique: true,
              name: "index_reactions_unique_per_user_target_emoji"
  end
end
