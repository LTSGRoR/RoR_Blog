class ClearExpiredSuspensionsJob < ApplicationJob
  queue_as :default

  def perform
    now = Time.current

    ids = User.where(suspended_until: ..now)
              .pluck(:id)
    return if ids.empty?

    User.where(id: ids).update_all(suspended_until: nil, suspended_time_zone: nil)

    broadcast_user_rows(ids)
    broadcast_summary
  end

  private

  def broadcast_user_rows(ids)
    # Single query: fetch updated users + their display order in one shot
    users = User.where(id: ids).index_by(&:id)
    order_ids = User.order(created_at: :desc).pluck(:id)

    users.each_value do |user|
      I18n.available_locales.each do |locale|
        I18n.with_locale(locale) do
          Turbo::StreamsChannel.broadcast_replace_to "users_#{locale}",
            target: "user_#{user.id}",
            partial: "users/user_row",
            locals: { user: user, i: order_ids.index(user.id) }
        end
      end
    rescue => e
      Rails.logger.error "ClearExpiredSuspensionsJob: broadcast failed for user=#{user.id} — #{e.message}"
    end
  end

  def broadcast_summary
    counts = User.pick(
      Arel.sql("COUNT(*)"),
      Arel.sql("COUNT(CASE WHEN banned_at IS NOT NULL THEN 1 END)"),
      Arel.sql("COUNT(CASE WHEN suspended_until IS NOT NULL AND suspended_until > NOW() THEN 1 END)")
    )

    total, banned, suspended = counts
    active = total - banned - suspended

    I18n.available_locales.each do |locale|
      I18n.with_locale(locale) do
        Turbo::StreamsChannel.broadcast_replace_to "users_#{locale}",
          target: "users_summary",
          partial: "users/users_summary",
          locals: { total_count: total, active_count: active, suspended_count: suspended, banned_count: banned }
      end
    end
  rescue => e
    Rails.logger.error "ClearExpiredSuspensionsJob: summary broadcast failed — #{e.message}"
  end
end
