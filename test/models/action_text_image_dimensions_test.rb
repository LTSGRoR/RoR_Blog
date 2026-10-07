# These attachment and view checks do not need a database.
ENV["RAILS_ENV"] ||= "test"
ENV["EMBEDDINGS_AUTO_RUN_ON_BOOT"] = "false"
require_relative "../../config/environment"
require "active_support/test_case"
require "minitest/autorun"

class ActionTextImageDimensionsTest < ActiveSupport::TestCase
  test "chosen image dimensions survive serialization and reopening" do
    attachable = Object.new
    attachable.define_singleton_method(:to_rich_text_attributes) do
      { width: 1200, height: 800, content_type: "image/png", previewable: true }
    end
    attachment = ActionText::Attachment.from_attributes({ width: 300, height: 200 }, attachable)

    assert_equal "300", attachment.with_full_attributes.node["width"]
    assert_equal "200", attachment.with_full_attributes.node["height"]
    assert_equal 300, attachment.to_trix_attachment.attributes["width"]
    assert_equal 200, attachment.to_trix_attachment.attributes["height"]
  end

  test "invalid dimensions fall back to original dimensions" do
    attachable = Object.new
    attachable.define_singleton_method(:to_rich_text_attributes) { { width: 1200, height: 800 } }
    attachment = ActionText::Attachment.from_attributes({ width: -1, height: "invalid" }, attachable)

    assert_equal 1200, attachment.full_attributes["width"]
    assert_equal 800, attachment.full_attributes["height"]
  end

  test "saved posts render the chosen dimensions and caption" do
    attachable = Object.new
    attachable.define_singleton_method(:representable?) { true }
    attachable.define_singleton_method(:representation) { |**_| "/test-image.png" }
    attachable.define_singleton_method(:filename) { ActiveStorage::Filename.new("test-image.png") }
    attachment = ActionText::Attachment.from_attributes({ width: 300, height: 200, caption: "My image" }, attachable)

    html = ApplicationController.render(partial: "active_storage/blobs/blob", locals: { blob: attachment })
    document = Nokogiri::HTML.fragment(html)
    assert_equal "300", document.at_css("img")["width"]
    assert_equal "200", document.at_css("img")["height"]
    assert_equal "My image", document.at_css("figcaption").text.strip
  end
end
