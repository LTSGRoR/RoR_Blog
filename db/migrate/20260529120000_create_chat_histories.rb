class CreateChatHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :chat_histories do |t|
      t.bigint :user_id, null: false
      t.bigint :post_id
      t.text :user_message
      t.text :bot_response
      t.string :provider
      t.jsonb :provider_meta, default: {}
      t.jsonb :meta, default: {}

      t.timestamps
    end

    add_index :chat_histories, :user_id
    add_index :chat_histories, :post_id
  end
end
