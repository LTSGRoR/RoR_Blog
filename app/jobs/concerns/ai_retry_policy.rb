# frozen_string_literal: true

# Shared retry policy for AI moderation jobs.
module AiRetryPolicy
  extend ActiveSupport::Concern

  private

  # Allow a bounded number of re-executions (Active Job tracks `executions`)
  # before falling back to the job's terminal state. `config` may be nil when
  # the failure happened before the configuration was resolved.
  def retryable?(config)
    max_retries = config&.fetch(:max_retries, 3).to_i
    executions < max_retries
  end

  def transient_error?(error_class_name, message)
    AiModeration::TransientErrors.transient?(error_class_name, message)
  end
end
