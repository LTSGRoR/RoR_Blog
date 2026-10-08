ENV["RAILS_ENV"] ||= "test"
ENV["EMBEDDINGS_AUTO_RUN_ON_BOOT"] = "false"
require_relative "../../config/environment"
require "active_support/test_case"
require "minitest/autorun"

class ActionTextAlignmentTest < ActiveSupport::TestCase
  test "block alignment survives storage, reading, and reopening" do
    %w[left center right].each do |direction|
      klass = "rt-align-#{direction}"
      html = %(<div class="#{klass}"><strong>Paragraph</strong></div><h1 class="#{klass}">Heading</h1><pre class="#{klass}">puts 'hello'</pre>)
      stored = ActionText::Content.new(html)
      [ stored.to_html, stored.to_trix_html, stored.to_rendered_html_with_layout ].each do |serialized|
        doc = Nokogiri::HTML.fragment(serialized)
        assert_equal 3, doc.css(".#{klass}").size
        assert_equal "Paragraph", doc.at_css("strong").text
        assert_equal "puts 'hello'", doc.at_css("pre").text
      end
    end
  end
end
