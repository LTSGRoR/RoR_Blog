require "json"

module AiModeration
  class DecisionParser
    Decision = Struct.new(:status, :confidence, :risk_score, :reason, :payload, keyword_init: true)
    CODE_FENCE_PREFIX = /\A```(?:json)?\s*/i
    CODE_FENCE_SUFFIX = /\s*```\z/

    class << self
      def parse(raw_text:, threshold:)
        payload = parse_payload(raw_text)
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

      private

      def parse_payload(raw_text)
        return raw_text.deep_stringify_keys if raw_text.is_a?(Hash)

        JSON.parse(normalize_raw_text(raw_text))
      end

      def normalize_raw_text(raw_text)
        raw_text.to_s.strip.sub(CODE_FENCE_PREFIX, "").sub(CODE_FENCE_SUFFIX, "").strip
      end
    end
  end
end
