class MigrateToFacebookEmojiSystem < ActiveRecord::Migration[8.0]
  def up
    # Remap existing reactions to new Facebook emoji system
    # Old: thumbs_up(0), cry(1), heart(2), thumbs_down(3), laugh(4), fire(5)
    # New: thumbs_up(0), heart(1), laugh(2), wow(3), sad(4), angry(5)

    execute "UPDATE reactions SET emoji_type = 1 WHERE emoji_type = 2"  # heart: 2 -> 1
    execute "UPDATE reactions SET emoji_type = 2 WHERE emoji_type = 4"  # laugh: 4 -> 2
    execute "DELETE FROM reactions WHERE emoji_type IN (1, 3, 5)"       # remove cry, thumbs_down, fire
  end

  def down
    # Reverse the operation - restore old system
    execute "DELETE FROM reactions WHERE emoji_type IN (1, 2, 3, 4, 5)"
    # Note: thumbs_up (0) is unchanged, other old values lost
  end
end
