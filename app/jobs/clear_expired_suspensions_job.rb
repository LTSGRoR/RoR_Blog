class ClearExpiredSuspensionsJob < ApplicationJob
  queue_as :default

  def perform
    expired_users = User.where.not(suspended_until: nil)
              .where("suspended_until <= ?", Time.current)
    ids = expired_users.pluck(:id)
    return if ids.empty?

    User.where(id: ids).update_all(suspended_until: nil, suspended_time_zone: nil)

    # Broadcast updates for each affected user row so the client can update just those DOM nodes.
    order_ids = User.order(created_at: :desc).pluck(:id)
    User.where(id: ids).find_each do |user|
      i = order_ids.index(user.id)
      begin
        Turbo::StreamsChannel.broadcast_replace_to "users",
          target: "user_#{user.id}",
          partial: "users/user_row",
          locals: { user: user, i: i }
      rescue => e
        Rails.logger.error("ClearExpiredSuspensionsJob broadcast error for user=#{user.id}: "+e.message)
      end
    end
  end
end
