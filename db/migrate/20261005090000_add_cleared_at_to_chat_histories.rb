class AddClearedAtToChatHistories < ActiveRecord::Migration[8.1]
  def change
    add_column :chat_histories, :cleared_at, :datetime
  end
end
