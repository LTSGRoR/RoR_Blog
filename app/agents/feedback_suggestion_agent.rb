require 'ruby_llm'

# Agent to generate feedback suggestions using Ollama/Gemma via RubyLLM
class FeedbackSuggestionAgent
  def initialize
    RubyLLM.configure do |config|
      config.ollama_api_base = "#{AIServices[:ollama_base_url].to_s.sub(%r{/*$}, "")}/v1"
      config.default_model = AIServices[:llm_model]
      config.request_timeout = AIServices[:suggestion_timeout]
    end
  end

  def generate_suggestions(revision, similar_revisions = [], current_admin = nil)
    return [] if similar_revisions.blank?
    feedback_patterns = extract_feedback_patterns(similar_revisions)
    context = build_context(revision, feedback_patterns, similar_revisions)
    suggestions = call_llm_for_suggestions(context, revision)
    suggestions
  rescue => e
    Rails.logger.error("FeedbackSuggestionAgent error: #{e.message}")
    []
  end

  private

  def extract_feedback_patterns(similar_revisions)
    patterns = {}
    
    similar_revisions.each do |rev|
      next if rev.review_note.blank?
      feedback_text = rev.review_note.downcase
      themes = extract_themes(feedback_text)
      themes.each do |theme|
        patterns[theme] = (patterns[theme] || 0) + 1
      end
    end
    patterns.sort_by { |_, count| -count }.to_h.take(5)
  end

  def extract_themes(text)
    themes = []
    
    theme_keywords = {
      'clarity' => ['unclear', 'confusing', 'ambiguous', 'vague', 'not clear', 'clarity'],
      'sources' => ['citation', 'source', 'reference', 'link', 'evidence', 'sources'],
      'tone' => ['tone', 'professional', 'respectful', 'hostile', 'aggressive'],
      'grammar' => ['grammar', 'spelling', 'punctuation', 'typo', 'syntax'],
      'relevance' => ['off-topic', 'irrelevant', 'tangent', 'scope'],
      'accuracy' => ['accurate', 'false', 'incorrect', 'factual', 'verify'],
      'structure' => ['structure', 'organization', 'flow', 'coherent', 'logical'],
      'length' => ['too long', 'too short', 'lengthy', 'brief', 'length'],
    }
    
    theme_keywords.each do |theme, keywords|
      if keywords.any? { |keyword| text.include?(keyword) }
        themes << theme
      end
    end
    
    themes
  end

  def build_context(revision, patterns, similar_revisions)
    post_title = revision.post.title
    post_body_excerpt = revision.body.to_plain_text[0..200]
    
    pattern_summary = if patterns.any?
      patterns.map { |theme, count| "- #{theme.capitalize} (#{count} similar rejections)" }.join("\n")
    else
      "No clear patterns detected."
    end
    
    similar_feedback_summary = similar_revisions.first(3).map do |rev|
      "- \"#{rev.review_note[0..100]}...\""
    end.join("\n")
    
    <<~CONTEXT
      You are an expert blog moderation assistant. An admin is about to reject a post revision.
      
      **Post Information:**
      - Title: "#{post_title}"
      - Excerpt: "#{post_body_excerpt}..."
      
      **Feedback Patterns from Similar Rejections:**
      #{pattern_summary}
      
      **Examples of Similar Past Rejections:**
      #{similar_feedback_summary}
      
      Based on these patterns and similar rejections, generate 2-3 specific, constructive feedback suggestions the admin could use when rejecting this post. Focus on actionable improvements.
      
      Format each suggestion as a single, concise sentence. Be professional and constructive.
    CONTEXT
  end

  def call_llm_for_suggestions(context, revision)
    prompt = "#{context}\n\nGenerate feedback suggestions:"
    
    Rails.logger.info("Calling LLM for feedback suggestions...")
    
    response = RubyLLM.chat(
      model: AIServices[:llm_model],
      provider: :ollama,
      assume_model_exists: true
    ).ask(prompt)

    # Parse response into suggestions
    suggestions_text = response.content.to_s
    parse_suggestions(suggestions_text)
  rescue => e
    Rails.logger.error("LLM call failed: #{e.message}")
    []
  end

  def parse_suggestions(response_text)
    # Split response into individual suggestions
    lines = response_text.split("\n").map(&:strip).reject(&:blank?)
    
    suggestions = []
    lines.each do |line|
      # Skip lines that look like headers or metadata
      next if line.start_with?('**') || line.start_with?('##')
      next if line.length < 10
      
      # Remove numbering (e.g., "1. ", "- ")
      suggestion = line.gsub(/^[\d.\-*\s]+/, '').strip
      
      if suggestion.length > 10 && suggestion.length < 500
        suggestions << suggestion
      end
    end
    
    # Return top 3 suggestions
    suggestions.take(3)
  end
end
