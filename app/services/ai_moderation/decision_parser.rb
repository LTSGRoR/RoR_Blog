require "json"

module AiModeration
  class DecisionParser
    Decision = Struct.new(:status, :confidence, :risk_score, :reason, :payload, keyword_init: true)

    class << self
      def parse(raw_text:, threshold:)
        payload = JSON.parse(raw_text.to_s)
        verdict = payload["verdict"].to_s
        confidence = payload["confidence"].to_f
        risk_score = payload["risk_score"].to_f
        reason = payload["reason"].to_s

        status = if verdict == "auto_approve" && confidence >= threshold
          :auto_approve
        else
          :needs_admin_review
        end

        Decision.new(
          status: status,
          confidence: confidence,
          risk_score: risk_score,
          reason: reason,
          payload: payload
        )
      rescue JSON::ParserError
        Decision.new(
          status: :failed,
          confidence: nil,
          risk_score: nil,
          reason: "Invalid JSON response from AI provider",
          payload: { "raw_response" => raw_text.to_s }
        )
      end
    end
  end
end
