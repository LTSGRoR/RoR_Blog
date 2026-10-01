module AiReviewSnapshot
  extend ActiveSupport::Concern

  private

  # Never hold a database lock across a provider request. The row version also
  # invalidates decisions after withdrawals, manual reviews and rich-text touches.
  def start_review(record)
    record.with_lock do
      return unless reviewable?(record)
      record.mark_ai_in_progress!
      payload = review_payload(record)
      { version: record.lock_version, token: record.ai_review_token, digest: review_digest(record), payload: payload }
    end
  end

  def with_current_review(record, snapshot)
    return unless record && snapshot

    record.with_lock do
      return unless reviewable?(record)
      return unless record.ai_review_token == snapshot[:token]
      unless record.lock_version == snapshot[:version] && review_digest(record) == snapshot[:digest]
        record.mark_ai_needs_admin_review!(reason: "Content or review state changed during AI review") if record.ai_review_in_progress?
        return
      end

      yield
    end
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def reviewable?(record)
    return false if record.ai_review_needs_admin_review? || record.ai_review_auto_approved?

    if record.is_a?(PostRevision)
      record.pending_review? && record.post.reload.published? && record.post.verified?
    else
      record.published? && !record.verified?
    end
  end

  def review_payload(record)
    if record.is_a?(PostRevision)
      AiModeration::ReviewPayloadBuilder.for_revision(record)
    else
      AiModeration::ReviewPayloadBuilder.for_post(record)
    end
  end

  def review_digest(record)
    payload = review_payload(record).except(:locale)
    payload[:tags] = payload[:tags].sort
    payload[:thumbnail_blob_id] = record.thumbnail_attachment&.blob_id
    Digest::SHA256.hexdigest(payload.to_json)
  end
end
