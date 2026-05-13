class ModerationSetting < ApplicationRecord
  PROVIDERS = {
    openai: "openai",
    gemini: "gemini",
    claude: "claude",
    mistral: "mistral"
  }.freeze

  DEFAULT_NEW_POST_INSTRUCTION = <<~TEXT.squish.freeze
    You are a moderation assistant for a public blog. Review a newly created post and decide whether it can be auto-approved.
    Prioritize safety, legality, hate/harassment prevention, and spam detection. Return strict JSON.
  TEXT

  DEFAULT_REVISION_INSTRUCTION = <<~TEXT.squish.freeze
    You are a moderation assistant for a public blog. Review a post revision and decide whether it can be auto-approved.
    Ensure the revision remains safe and policy-compliant. Return strict JSON.
  TEXT

  before_save :track_model_change

  encrypts :api_key

  validates :provider, presence: true
  validates :provider, inclusion: { in: PROVIDERS.values }
  validates :ai_model, presence: true
  validates :api_key, presence: true, if: :provider_requires_api_key?
  validates :request_timeout_seconds, numericality: { greater_than: 0 }
  validates :max_retries, numericality: { greater_than: 0 }
  validates :auto_approve_threshold, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
  validates :new_post_instruction, presence: true
  validates :revision_instruction, presence: true

  def self.current
    first_or_create!(
      provider: "mistral",
      ai_model: "mistral-small-latest",
      auto_approve_threshold: 0.9,
      request_timeout_seconds: 30,
      max_retries: 3,
      auto_review_enabled: true,
      api_key: "default",
      new_post_instruction: DEFAULT_NEW_POST_INSTRUCTION,
      revision_instruction: DEFAULT_REVISION_INSTRUCTION
    )
  end

  private

  def track_model_change
    @old_model = ai_model_was
    @new_model = ai_model
  end

  def provider_requires_api_key?
    provider.present?
  end
end
