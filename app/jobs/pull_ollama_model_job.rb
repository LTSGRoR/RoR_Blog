class PullOllamaModelJob < ApplicationJob
  queue_as :default

  def perform(model_name)
    return if model_name.blank?

    result = AiModeration::ModelPuller.new(model_name).call

    if result[:success]
      Rails.logger.info("✓ Model pull completed: #{model_name}")
    else
      Rails.logger.warn("✗ Model pull failed: #{result[:message]}")
    end
  end
end
