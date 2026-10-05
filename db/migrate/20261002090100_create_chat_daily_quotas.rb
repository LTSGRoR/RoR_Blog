class CreateChatDailyQuotas < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_daily_quotas do |t|
      t.date :day, null: false
      t.integer :requests_count, null: false, default: 0
    end
    add_index :chat_daily_quotas, :day, unique: true
  end
end
