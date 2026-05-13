require "test_helper"

class AiModeration::DecisionParserTest < ActiveSupport::TestCase
  test "auto approve when verdict and confidence pass threshold" do
    raw = {
      verdict: "auto_approve",
      confidence: 0.96,
      risk_score: 0.08,
      reason: "clean"
    }.to_json

    decision = AiModeration::DecisionParser.parse(raw_text: raw, threshold: 0.9)

    assert_equal :auto_approve, decision.status
    assert_equal 0.96, decision.confidence
    assert_equal 0.08, decision.risk_score
  end

  test "falls back to admin review when confidence below threshold" do
    raw = {
      verdict: "auto_approve",
      confidence: 0.55,
      risk_score: 0.2,
      reason: "uncertain"
    }.to_json

    decision = AiModeration::DecisionParser.parse(raw_text: raw, threshold: 0.9)

    assert_equal :needs_admin_review, decision.status
  end

  test "parses fenced json responses" do
    raw = <<~TEXT
      ```json
      {
        "verdict": "auto_approve",
        "confidence": 0.99,
        "risk_score": 0.01,
        "reason": "clean"
      }
      ```
    TEXT

    decision = AiModeration::DecisionParser.parse(raw_text: raw, threshold: 0.9)

    assert_equal :auto_approve, decision.status
    assert_equal 0.99, decision.confidence
    assert_equal 0.01, decision.risk_score
    assert_equal "clean", decision.reason
  end

  test "marks failed for invalid json" do
    decision = AiModeration::DecisionParser.parse(raw_text: "not json", threshold: 0.9)

    assert_equal :failed, decision.status
    assert_includes decision.reason, "Invalid JSON"
  end
end
