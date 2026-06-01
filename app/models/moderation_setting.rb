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

  DEFAULT_ASSISTANT_PROMPT = <<~TEXT.squish.freeze
    You are an AI assistant for a public blogging platform. Your primary goal is to help users discover relevant blog posts, authors, and topics based on their interests and questions.
    Use the provided context to:
    * Recommend the most relevant blog posts.
    * Summarize key insights from matching content.
    * Explain how recommended posts relate to the user's query.
    * Suggest related topics, articles, or authors when appropriate.
    When multiple posts are relevant, compare them briefly and explain the differences so users can choose what best fits their needs.
    If the available context does not fully answer the user's question, provide the most relevant information from the context and clearly state what information is missing. Do not invent facts, blog posts, authors, or details that are not present in the provided context.
    Be concise, helpful, and user-focused. Prioritize helping users find and understand the most relevant content available on the platform.
    * Do not use markdown formatting in your response. Plain text only.
  TEXT

  before_save :track_model_change

  encrypts :api_key

  validates :provider, presence: true
  validates :provider, inclusion: { in: PROVIDERS.values }
  validates :ai_model, presence: true
  validates :api_key, presence: true, if: :api_key_required?
  validates :request_timeout_seconds, numericality: { greater_than: 0 }
  validates :max_retries, numericality: { greater_than: 0 }
  validates :auto_approve_threshold, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
  validates :new_post_instruction, presence: true
  validates :revision_instruction, presence: true
  validates :assistant_prompt, presence: true

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
      revision_instruction: DEFAULT_REVISION_INSTRUCTION,
      assistant_prompt: DEFAULT_ASSISTANT_PROMPT
    )
  end

  private

  def track_model_change
    @old_model = ai_model_was
    @new_model = ai_model
  end

  def api_key_required?
    return false unless provider.present?
    return false if api_key.present?

    persisted_key = persisted? ? api_key_in_database.to_s : ""
    persisted_key.blank?
  end
end
