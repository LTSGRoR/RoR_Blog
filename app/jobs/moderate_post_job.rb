class ModeratePostJob < ApplicationJob
  queue_as :default

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
      handle_failure!(post: post, config: config, reason: decision.reason)
    end
  rescue StandardError => e
    log_event("error", post_id: post_id, error_class: e.class.name, error_message: e.message)
    post&.mark_ai_failed!(reason: e.message)
    raise e if retryable?(config)

    post&.mark_ai_needs_admin_review!(reason: e.message)
    log_event("fallback_after_retries", post_id: post_id, reason: e.message)
  end

  private

  def retryable?(config)
    max_retries = config&.fetch(:max_retries, 3).to_i
    executions < max_retries
  end

  def handle_failure!(post:, config:, reason:)
    post.mark_ai_failed!(reason: reason)
    log_event("decision_failed", post_id: post.id, reason: reason)
    raise StandardError, reason if retryable?(config)

    post.mark_ai_needs_admin_review!(reason: reason)
    log_event("fallback_after_retries", post_id: post.id, reason: reason)
  end

  def log_event(event, payload = {})
    Rails.logger.info({ event: "ai_moderation_post_#{event}" }.merge(payload).to_json)
  end
end
