class AddAssistantPromptToModerationSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :moderation_settings, :assistant_prompt, :text
  end
end
