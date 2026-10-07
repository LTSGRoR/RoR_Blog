# Action Text normally replaces saved dimensions with the blob's original
# dimensions when rebuilding attachments. Keep the author's chosen size.
module ActionTextImageDimensions
  def full_attributes
    attributes = super
    dimensions = %w[width height].to_h { |name| [name, Integer(node[name], exception: false)] }
    if dimensions.values.all? { |value| value&.positive? }
      attributes.merge(dimensions.transform_values(&:to_s))
    else
      attributes
    end
  end
end

Rails.application.config.to_prepare do
  ActionText::Attachment.prepend(ActionTextImageDimensions) unless ActionText::Attachment < ActionTextImageDimensions
end
