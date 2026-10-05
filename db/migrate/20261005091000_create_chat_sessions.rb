class CreateChatSessions < ActiveRecord::Migration[8.1]
  def up
    create_table :chat_sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :chat_sessions, [ :user_id, :deleted_at, :id ]
    add_reference :chat_histories, :chat_session, foreign_key: true
    execute <<~SQL
      INSERT INTO chat_sessions (user_id, title, created_at, updated_at)
      SELECT history.user_id,
        (SELECT LEFT(previous.user_message, 80) FROM chat_histories previous
         WHERE previous.user_id = history.user_id AND previous.cleared_at IS NULL
         ORDER BY previous.id LIMIT 1),
        MIN(history.created_at), MAX(history.updated_at)
      FROM chat_histories history GROUP BY history.user_id;
      UPDATE chat_histories SET chat_session_id = chat_sessions.id
      FROM chat_sessions WHERE chat_sessions.user_id = chat_histories.user_id;
    SQL
    change_column_null :chat_histories, :chat_session_id, false
    add_index :chat_histories, [ :chat_session_id, :cleared_at, :id ], name: "index_chat_histories_on_session_visibility"
  end

  def down
    remove_reference :chat_histories, :chat_session, foreign_key: true
    drop_table :chat_sessions
  end
end
