class ClearExpiredSuspensionsWorker
  include Sidekiq::Job
  sidekiq_options queue: :default

  def perform(*_args)
    ClearExpiredSuspensionsJob.perform_now
  end
end
