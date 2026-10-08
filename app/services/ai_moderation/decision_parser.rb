require "json"

module AiModeration
  class DecisionParser
    Decision = Struct.new(:status, :confidence, :risk_score, :reason, :payload, keyword_init: true)
    CODE_FENCE_PREFIX = /\A```(?:json)?\s*/i
    CODE_FENCE_SUFFIX = /\s*```\z/

    class << self
      def parse(raw_text:, threshold:)
        payload = parse_payload(raw_text)
        validate_payload!(payload)
        threshold = Float(threshold)
        raise ArgumentError unless threshold.finite? && threshold.between?(0, 1)
        verdict = payload["verdict"]
        confidence = payload["confidence"]
        risk_score = payload["risk_score"]
        reason = payload["reason"]

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
      rescue JSON::ParserError, ArgumentError, TypeError
        Decision.new(
          status: :failed,
          confidence: nil,
          risk_score: nil,
          reason: "Invalid moderation response from AI provider",
          payload: { "raw_response" => raw_text.to_s }
        )
      end

      private

      def validate_payload!(payload)
        raise ArgumentError unless payload.is_a?(Hash)
        raise ArgumentError unless payload.keys.sort == %w[confidence reason risk_score verdict]
        raise ArgumentError unless %w[auto_approve needs_admin_review].include?(payload["verdict"])
        %w[confidence risk_score].each do |key|
          value = payload[key]
          raise ArgumentError unless value.is_a?(Numeric) && value.finite? && value.between?(0, 1)
        end
        raise ArgumentError unless payload["reason"].is_a?(String) && payload["reason"].strip.present?
      end

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
