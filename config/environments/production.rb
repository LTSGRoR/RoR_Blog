require "active_support/core_ext/integer/time"

Rails.application.configure do
  force_ssl = ActiveModel::Type::Boolean.new.cast(ENV.fetch("FORCE_SSL", true))
  app_host = ENV.fetch("APP_HOST", "localhost")
  app_protocol = ENV.fetch("APP_PROTOCOL", force_ssl ? "https" : "http")

  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl = force_ssl

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = force_ssl

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Background jobs: Sidekiq (consistent with development)
  config.active_job.queue_adapter = :sidekiq

  # Outgoing mail in production. Configure via SMTP_* env vars (same names as
  # development). Falls back to :smtp with no address only if SMTP_ADDRESS is
  # blank -- Devise and notifications need a real host, so set SMTP_ADDRESS.
  if ENV["SMTP_ADDRESS"].present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = {
      address:              ENV["SMTP_ADDRESS"],
      port:                 ENV.fetch("SMTP_PORT", 587).to_i,
      domain:               ENV.fetch("SMTP_DOMAIN", app_host),
      user_name:            ENV["SMTP_USERNAME"].presence,
      password:             ENV["SMTP_PASSWORD"].presence,
      authentication:       :plain,
      enable_starttls_auto: true
    }
  else
    # Fail fast at boot instead of silently dropping mail via :smtp to localhost.
    warn "[production] SMTP_ADDRESS is blank; mail delivery will fail. Set SMTP_ADDRESS/SMTP_USERNAME/SMTP_PASSWORD."
    config.action_mailer.delivery_method = :smtp
  end
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = {
    host: app_host,
    protocol: app_protocol
  }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # APP_HOST must be a concrete hostname (it is also used for mailer URLs and
  # SMTP_DOMAIN fallback), e.g. APP_HOST=2c4c-118-70-127-173.ngrok-free.app
  # Do NOT set APP_HOST="*.ngrok-free.app" -- mailer links would break and the
  # hosts allowlist would not match. For wildcard subdomains (ngrok rotates the
  # prefix on every restart), use ADDITIONAL_HOSTS with a regex entry:
  #   ADDITIONAL_HOSTS=/.*\.ngrok-free\.app/
  # or a leading-dot suffix: ADDITIONAL_HOSTS=.ngrok-free.app
  config.hosts << app_host unless app_host == "localhost"
  ENV.fetch("ADDITIONAL_HOSTS", "").split(",").each do |extra_host|
    host = extra_host.strip
    next if host.empty?
    if host.start_with?("/") && host.end_with?("/") && host.length > 2
      config.hosts << Regexp.new(host[1..-2])
    elsif host.start_with?(".")
      config.hosts << Regexp.new(".*#{Regexp.escape(host)}$")
    else
      config.hosts << host
    end
  end
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
