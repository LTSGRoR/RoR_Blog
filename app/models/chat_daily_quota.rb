class ChatDailyQuota < ApplicationRecord
  self.table_name = "chat_daily_quotas"
  # Bootstrap an existing day's usage once. The advisory lock is only needed
  # when the day has no counter, including the first day after deployment.
  def self.for_time(time)
    day = time.to_date
    find_by(day: day) || transaction do
      connection.execute("SELECT pg_advisory_xact_lock(741902001)")
      find_by(day: day) || create!(day: day,
        requests_count: ChatHistory.where(created_at: time.beginning_of_day...time.next_day.beginning_of_day).count)
    end
  end
end
