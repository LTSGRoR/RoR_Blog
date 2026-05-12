class AddApiKeyToModerationSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :moderation_settings, :api_key, :text
  end
end
