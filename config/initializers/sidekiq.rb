require "sidekiq/cron/job"

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

  schedule_file = Rails.root.join("config/sidekiq_schedule.yml")
  if File.exist?(schedule_file)
    schedule = YAML.safe_load(File.read(schedule_file), aliases: true) || {}
    Sidekiq::Cron::Job.load_from_hash(schedule)
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end
