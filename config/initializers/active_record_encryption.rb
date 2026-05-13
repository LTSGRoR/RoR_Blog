require "securerandom"

encryption_credentials = Rails.application.credentials[:active_record_encryption] || {}

resolve_encryption_value = lambda do |env_key, credentials_key|
  ENV[env_key].presence || encryption_credentials[credentials_key].presence
end

Rails.application.config.active_record.encryption.primary_key =
  resolve_encryption_value.call("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY", :primary_key)
Rails.application.config.active_record.encryption.deterministic_key =
  resolve_encryption_value.call("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY", :deterministic_key)
Rails.application.config.active_record.encryption.key_derivation_salt =
  resolve_encryption_value.call("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT", :key_derivation_salt)

if Rails.env.test?
  Rails.application.config.active_record.encryption.primary_key ||= SecureRandom.hex(16)
  Rails.application.config.active_record.encryption.deterministic_key ||= SecureRandom.hex(16)
  Rails.application.config.active_record.encryption.key_derivation_salt ||= SecureRandom.hex(16)
end