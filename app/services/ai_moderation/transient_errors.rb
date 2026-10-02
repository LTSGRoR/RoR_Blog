# frozen_string_literal: true

module AiModeration
  # Central policy for classifying AI moderation failures as transient
  # (worth retrying) or permanent (go straight to the terminal state).
  #
  # Class names are compared as strings and never constantized, so listing
  # gem-specific classes (e.g. RubyLLM::RateLimitError) is safe even when the
  # constant is not loaded.
  module TransientErrors
    TRANSIENT_ERROR_CLASSES = %w[
      Timeout::Error
      Net::OpenTimeout
      Net::ReadTimeout
      Errno::ECONNRESET
      Errno::ETIMEDOUT
      Faraday::TimeoutError
      Faraday::ConnectionFailed
      RubyLLM::RateLimitError
    ].freeze

    TRANSIENT_MESSAGE_PATTERN = /timeout|temporarily unavailable|connection reset|broken pipe|retry|temporarily|transient|rate limit|too many requests|\b429\b/i

    class << self
      def transient?(error_class_name, message)
        return true if TRANSIENT_ERROR_CLASSES.include?(error_class_name.to_s)

        message.to_s.match?(TRANSIENT_MESSAGE_PATTERN)
      end
    end
  end
end
