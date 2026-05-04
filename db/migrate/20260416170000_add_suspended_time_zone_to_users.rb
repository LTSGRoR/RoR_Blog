class AddSuspendedTimeZoneToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :suspended_time_zone, :string
    add_index :users, :suspended_time_zone
  end
end
