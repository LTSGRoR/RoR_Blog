module RichTextLinksHelper
  def rich_text_links_in_new_window(sanitized_html)
    fragment = Nokogiri::HTML.fragment(sanitized_html.to_s)
    fragment.css("a[href]").each do |link|
      link["target"] = "_blank"
      link["rel"] = (link["rel"].to_s.split + %w[noopener noreferrer]).uniq.join(" ")
    end
    fragment.to_html.html_safe
  end
end
