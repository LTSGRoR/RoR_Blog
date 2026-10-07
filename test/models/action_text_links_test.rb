ENV["RAILS_ENV"] ||= "test"
ENV["EMBEDDINGS_AUTO_RUN_ON_BOOT"] = "false"
require_relative "../../config/environment"
require "active_support/test_case"
require "minitest/autorun"

class ActionTextLinksTest < ActiveSupport::TestCase
  test "rendered content opens links safely in a new browsing context" do
    content = ActionText::Content.new('<div><a href="https://example.com"><strong>Example</strong></a> <a href="/posts/1">Post</a></div>')
    rendered = Nokogiri::HTML.fragment(content.to_rendered_html_with_layout)
    assert_equal 2, rendered.css("a[href]").size
    rendered.css("a[href]").each do |link|
      assert_equal "_blank", link["target"]
      assert_includes link["rel"].split, "noopener"
      assert_includes link["rel"].split, "noreferrer"
    end
    assert_equal "Example", rendered.at_css("a strong").text
    refute_includes content.to_trix_html, 'target="_blank"'
  end

  test "unsafe URLs stay sanitized before adding new window attributes" do
    content = ActionText::Content.new('<div><a href="javascript:alert(1)">Unsafe</a></div>')
    rendered = Nokogiri::HTML.fragment(content.to_rendered_html_with_layout)
    assert_empty rendered.css("a[href]")
  end
end
