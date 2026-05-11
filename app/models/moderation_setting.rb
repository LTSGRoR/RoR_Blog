class ModerationSetting < ApplicationRecord
  DEFAULT_NEW_POST_INSTRUCTION = <<~TEXT.squish.freeze
    You are a moderation assistant for a public blog. Review a newly created post and decide whether it can be auto-approved.
    Prioritize safety, legality, hate/harassment prevention, and spam detection. Return strict JSON.
  TEXT

  DEFAULT_REVISION_INSTRUCTION = <<~TEXT.squish.freeze
    You are a moderation assistant for a public blog. Review a post revision and decide whether it can be auto-approved.
    Ensure the revision remains safe and policy-compliant. Return strict JSON.
  TEXT

  before_save :track_model_change
  after_commit :pull_new_model, if: :model_changed_and_saved?

  validates :provider, presence: true
  validates :ai_model, presence: true
  validates :request_timeout_seconds, numericality: { greater_than: 0 }
  validates :max_retries, numericality: { greater_than: 0 }
  validates :auto_approve_threshold, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
  validates :new_post_instruction, presence: true
  validates :revision_instruction, presence: true

  def self.current
    first_or_create!(
      provider: "ollama",
      ai_model: "gemma4:latest",
      auto_approve_threshold: 0.9,
      request_timeout_seconds: 30,
      max_retries: 3,
      auto_review_enabled: true,
      new_post_instruction: DEFAULT_NEW_POST_INSTRUCTION,
      revision_instruction: DEFAULT_REVISION_INSTRUCTION
    )
  end

  private

  def track_model_change
    @old_model = ai_model_was
    @new_model = ai_model
  end

  def model_changed_and_saved?
    @old_model.present? && @old_model != @new_model && @new_model.present?
  end

  def pull_new_model
    PullOllamaModelJob.perform_later(@new_model)
    Rails.logger.info("Queued model pull for: #{@new_model}")
  end
end
