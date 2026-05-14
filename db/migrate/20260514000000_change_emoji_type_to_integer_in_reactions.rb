class ChangeEmojiTypeToIntegerInReactions < ActiveRecord::Migration[8.0]
  def up
    add_column :reactions, :emoji_type_int, :integer

    execute <<~SQL
      UPDATE reactions
      SET emoji_type_int = CASE emoji_type
        WHEN '👍' THEN 0
        WHEN '🚀' THEN 1
        WHEN '❤️' THEN 2
      END
    SQL

    remove_column :reactions, :emoji_type
    rename_column :reactions, :emoji_type_int, :emoji_type
    change_column_null :reactions, :emoji_type, false
  end

  def down
    add_column :reactions, :emoji_type_str, :string

    execute <<~SQL
      UPDATE reactions
      SET emoji_type_str = CASE emoji_type
        WHEN 0 THEN '👍'
        WHEN 1 THEN '🚀'
        WHEN 2 THEN '❤️'
      END
    SQL

    remove_column :reactions, :emoji_type
    rename_column :reactions, :emoji_type_str, :emoji_type
    change_column_null :reactions, :emoji_type, false
  end
end
