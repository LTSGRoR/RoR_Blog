class ModeratePostJob < ApplicationJob
  queue_as :default

  TRANSIENT_ERROR_CLASSES = %w[
    Timeout::Error
    Net::OpenTimeout
    Net::ReadTimeout
    Errno::ECONNRESET
    Errno::ETIMEDOUT
    Faraday::TimeoutError
    Faraday::ConnectionFailed
  ].freeze

  def perform(post_id)
    log_event("start", post_id: post_id)

    post = Post.includes(:tags).find_by(id: post_id)
    unless post
      log_event("skip_missing_post", post_id: post_id)
      return
    end

    unless post.published?
      log_event("skip_not_published", post_id: post.id)
      return
    end

    if post.verified?
      log_event("skip_already_verified", post_id: post.id)
      return
    end

    config = AiModeration::Configuration.current
    unless config.fetch(:auto_review_enabled)
      log_event("skip_feature_disabled", post_id: post.id)
      return
    end

    post.mark_ai_in_progress!

    decision = AiModeration::Client.new(config: config).review(
      instruction: config.fetch(:new_post_instruction),
      content_payload: AiModeration::ReviewPayloadBuilder.for_post(post)
    )

    log_event(
      "decision_received",
      post_id: post.id,
      status: decision.status,
      confidence: decision.confidence,
      risk_score: decision.risk_score
    )

    post.record_ai_decision!(decision: decision, config: config)

    if decision.status == :auto_approve
      admin = AiModeration::ActorResolver.admin_user
      if admin.present?
        post.verify!(admin)
        post.mark_ai_auto_approved!
        log_event("auto_approved", post_id: post.id, admin_id: admin.id)
      else
        post.mark_ai_needs_admin_review!(reason: "No admin account available for AI auto-approval")
        log_event("fallback_missing_admin", post_id: post.id)
      end
    elsif decision.status == :needs_admin_review
      post.mark_ai_needs_admin_review!(reason: decision.reason)
      log_event("needs_admin_review", post_id: post.id, reason: decision.reason)
    else
      handle_failure!(post: post, config: config, decision: decision)
    end
  rescue StandardError => e
    log_event("error", post_id: post_id, error_class: e.class.name, error_message: e.message)

    unless post&.ai_review_failed?
      post&.mark_ai_failed!(reason: e.message)
    end

    raise e if retryable?(config) && transient_error?(e.class.name, e.message)
  end

  private

  def retryable?(config)
    max_retries = config&.fetch(:max_retries, 3).to_i
    executions < max_retries
  end

  def handle_failure!(post:, config:, decision:)
    reason = decision.reason
    error_class = decision.payload.is_a?(Hash) ? decision.payload["error_class"] : nil

    post.mark_ai_failed!(reason: reason)
    log_event("decision_failed", post_id: post.id, reason: reason, error_class: error_class)

    if retryable?(config) && transient_error?(error_class, reason)
      raise StandardError, reason
    end
  end

  def transient_error?(error_class_name, message)
    error_class = error_class_name.to_s
    msg = message.to_s

    return true if TRANSIENT_ERROR_CLASSES.include?(error_class)

    # Match transient infrastructure errors that could be retried
    msg.match?(/timeout|temporarily unavailable|connection reset|broken pipe|retry|temporarily|transient/i)
  end

  def log_event(event, payload = {})
    Rails.logger.info({ event: "ai_moderation_post_#{event}" }.merge(payload).to_json)
  end
end
