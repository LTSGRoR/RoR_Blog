class ClearExpiredSuspensionsWorker
  include Sidekiq::Worker
  sidekiq_options queue: :default

  def perform(*_args)
    ClearExpiredSuspensionsJob.perform_now
  end
end
