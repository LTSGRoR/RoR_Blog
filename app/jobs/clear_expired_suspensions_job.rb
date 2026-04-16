class ClearExpiredSuspensionsJob < ApplicationJob
  queue_as :default

  def perform
    User.where.not(suspended_until: nil)
        .where("suspended_until <= ?", Time.current)
        .update_all(suspended_until: nil)
  end
end
