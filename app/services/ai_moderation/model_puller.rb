module AiModeration
  class ModelPuller
    def initialize(model_name, api_base: nil)
      @model_name = model_name
      @api_base = api_base || AiModeration::Configuration.current[:ollama_api_base]
    end

    def call
      return { success: true, message: "No model specified" } if @model_name.blank?

      Rails.logger.info("Pulling Ollama model: #{@model_name}")

      uri = URI.join(@api_base, "/api/pull")
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 300 # 5 minutes for pull

      request = Net::HTTP::Post.new(uri.request_uri)
      request["Content-Type"] = "application/json"
      request.body = { name: @model_name }.to_json

      response = http.request(request)

      if response.is_a?(Net::HTTPSuccess)
        { success: true, message: "Model pulled successfully" }
      else
        { success: false, message: "Failed to pull model: #{response.body}" }
      end
    rescue => e
      Rails.logger.error("Model pull error: #{e.message}")
      { success: false, message: "Error pulling model: #{e.message}" }
    end
  end
end
