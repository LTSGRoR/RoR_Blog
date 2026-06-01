Rails.application.config.after_initialize do
  next unless defined?(Rails::Server)

  auto_bootstrap_enabled = ActiveModel::Type::Boolean.new.cast(
    ENV.fetch("EMBEDDINGS_AUTO_RUN_ON_BOOT", "true")
  )
  next unless auto_bootstrap_enabled

  begin
    Embeddings::Bootstrap.enqueue_missing_verified_posts!
  rescue StandardError => e
    Rails.logger.error("Embeddings bootstrap failed: #{e.class} - #{e.message}")
  end
end
