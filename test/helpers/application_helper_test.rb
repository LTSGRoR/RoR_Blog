require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "localized_time_tag renders machine-readable local time markup" do
    value = Time.utc(2026, 5, 21, 14, 30)

    rendered = localized_time_tag(value, class: "timestamp")

    assert_includes rendered, "<time"
    assert_includes rendered, "class=\"timestamp\""
    assert_includes rendered, "data-controller=\"local-time\""
    assert_includes rendered, "data-local-time-format-value=\"short\""
    assert_includes rendered, "datetime=\"#{value.iso8601}\""
    assert_includes rendered, ERB::Util.html_escape(I18n.l(value, format: :short))
  end

  test "translated html keys preserve localized time tags" do
    value = Time.utc(2026, 5, 21, 14, 30)

    rendered = I18n.t("users.profile.member_since_html", date: localized_time_tag(value))

    assert_includes rendered, "Member since"
    assert_includes rendered, "<time"
    assert_includes rendered, "data-controller=\"local-time\""
  end
end
