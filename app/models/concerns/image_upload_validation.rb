module ImageUploadValidation
  extend ActiveSupport::Concern

  IMAGE_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

  private

  def validate_image_upload(name, maximum_size:)
    # Legacy uploads must not prevent unrelated actions such as banning a user.
    return unless new_record? || attachment_changes.key?(name.to_s)

    upload = public_send(name)
    return unless upload.attached?

    errors.add(name, "must be a JPEG, PNG, GIF or WebP image") unless IMAGE_TYPES.include?(upload.blob.content_type)
    errors.add(name, "must be smaller than #{maximum_size / 1.megabyte}MB") if upload.blob.byte_size > maximum_size
  end
end
