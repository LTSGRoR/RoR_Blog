class RenameModelNameInModerationSettings < ActiveRecord::Migration[8.0]
  def change
    return unless column_exists?(:moderation_settings, :model_name)

    rename_column :moderation_settings, :model_name, :ai_model
  end
end
