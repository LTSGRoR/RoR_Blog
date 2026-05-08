module DeviseHelper
  # Render Devise resource error messages in a Tailwind-friendly block.
  # Usage in views: <%= devise_error_messages! %>
  def devise_error_messages!
    return nil unless defined?(resource) && resource.present? && resource.errors.any?

    sentence = I18n.t("errors.messages.not_saved", count: resource.errors.count,
                                                 resource: resource.class.model_name.human.downcase)

    messages = resource.errors.full_messages.map { |msg| content_tag(:li, msg) }.join.html_safe

    content_tag(:div, id: "error_explanation", class: "mb-4 bg-red-50 border border-red-200 p-4 rounded") do
      concat content_tag(:h2, sentence, class: "text-red-800 font-semibold")
      concat content_tag(:ul, messages, class: "mt-2 text-sm text-red-600 list-disc pl-5")
    end
  end
end
