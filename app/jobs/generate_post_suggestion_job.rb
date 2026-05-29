class GeneratePostSuggestionJob < ApplicationJob
  queue_as :default

  def perform(chat_history_id)
    chat = ChatHistory.find_by(id: chat_history_id)
    return unless chat
    return if chat.bot_response.present?

    service = AiGeneration::Service.new
    result = service.generate(prompt: chat.user_message, user: chat.user, context: { post_id: chat.post_id })

    chat.update!(bot_response: result[:result], provider: result[:provider], provider_meta: result[:meta])

    Turbo::StreamsChannel.broadcast_append_to(
      "chat_histories_user_#{chat.user_id}",
      partial: "chat_histories/chat_history_item",
      locals: { chat_history: chat }
    )
  rescue StandardError => e
    Rails.logger.error("GeneratePostSuggestionJob failed for chat_history_id=#{chat_history_id}: #{e.class} - #{e.message}")
    chat&.update!(bot_response: "", provider_meta: { error: e.message }) if chat
    raise
  end
end
