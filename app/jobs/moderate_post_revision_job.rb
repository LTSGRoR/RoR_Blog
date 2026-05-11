class ModeratePostRevisionJob < ApplicationJob
  queue_as :default

  def perform(post_revision_id)
    log_event("start", post_revision_id: post_revision_id)

    revision = PostRevision.includes(:tags, :post).find_by(id: post_revision_id)
    unless revision
      log_event("skip_missing_revision", post_revision_id: post_revision_id)
      return
    end

    unless revision.pending_review?
      log_event("skip_not_pending", post_revision_id: revision.id, moderation_status: revision.moderation_status)
      return
    end

    config = AiModeration::Configuration.current
    unless config.fetch(:auto_review_enabled)
      log_event("skip_feature_disabled", post_revision_id: revision.id)
      return
    end

    revision.mark_ai_in_progress!

    decision = AiModeration::Client.new(config: config).review(
      instruction: config.fetch(:revision_instruction),
      content_payload: AiModeration::ReviewPayloadBuilder.for_revision(revision)
    )

    log_event(
      "decision_received",
      post_revision_id: revision.id,
      status: decision.status,
      confidence: decision.confidence,
      risk_score: decision.risk_score
    )

    revision.record_ai_decision!(decision: decision, config: config)

    if decision.status == :auto_approve
      admin = AiModeration::ActorResolver.admin_user
      if admin.present?
        revision.approve!(admin: admin, note: "Auto-approved by AI moderation")
        revision.mark_ai_auto_approved!
        log_event("auto_approved", post_revision_id: revision.id, admin_id: admin.id)
      else
        revision.mark_ai_needs_admin_review!(reason: "No admin account available for AI auto-approval")
        log_event("fallback_missing_admin", post_revision_id: revision.id)
      end
    elsif decision.status == :needs_admin_review
      revision.mark_ai_needs_admin_review!(reason: decision.reason)
      log_event("needs_admin_review", post_revision_id: revision.id, reason: decision.reason)
    else
      handle_failure!(revision: revision, config: config, reason: decision.reason)
    end
  rescue StandardError => e
    log_event("error", post_revision_id: post_revision_id, error_class: e.class.name, error_message: e.message)
    revision&.mark_ai_failed!(reason: e.message)
    raise e if retryable?(config)

    revision&.mark_ai_needs_admin_review!(reason: e.message)
    log_event("fallback_after_retries", post_revision_id: post_revision_id, reason: e.message)
  end

  private

  def retryable?(config)
    max_retries = config&.fetch(:max_retries, 3).to_i
    executions < max_retries
  end

  def handle_failure!(revision:, config:, reason:)
    revision.mark_ai_failed!(reason: reason)
    log_event("decision_failed", post_revision_id: revision.id, reason: reason)
    raise StandardError, reason if retryable?(config)

    revision.mark_ai_needs_admin_review!(reason: reason)
    log_event("fallback_after_retries", post_revision_id: revision.id, reason: reason)
  end

  def log_event(event, payload = {})
    Rails.logger.info({ event: "ai_moderation_revision_#{event}" }.merge(payload).to_json)
  end
end
