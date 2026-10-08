require "sidekiq/cron/job"

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }

  # Forward worker failures to Rails error subscribers without exposing job
  # arguments (which can contain private chat messages or provider credentials).
  config.error_handlers << ->(error, context, _config) do
    job = context[:job] || context["job"] || {}
    Rails.error.report(error, handled: false, source: "sidekiq", context: {
      job_class: job["wrapped"] || job["class"],
      job_id: job["jid"],
      queue: job["queue"]
    })
  end

  schedule_file = Rails.root.join("config/sidekiq_schedule.yml")
  if File.exist?(schedule_file)
    schedule = YAML.safe_load(File.read(schedule_file), aliases: true) || {}
    Sidekiq::Cron::Job.load_from_hash(schedule)
  end
end

# Load timezone aliases for server-side normalization
TIMEZONE_ALIASES = if File.exist?(Rails.root.join("config", "timezone_aliases.yml"))
  YAML.safe_load(File.read(Rails.root.join("config", "timezone_aliases.yml"))) || {}
else
  {}
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("REDIS_URL", "redis://localhost:6379/0") }
end
