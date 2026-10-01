require "application_system_test_case"

class TagSuggestionsTest < ApplicationSystemTestCase
  test "hostile tag names remain literal text and attribute data" do
    visit new_user_session_path(locale: :en)
    hostile_name = %q("><img src=x onerror="window.tagInjected=true">)
    source = Rails.root.join("app/javascript/controllers/tag_input_controller.js").read
      .sub(/^import .*\n/, "")
      .sub("export default class", "class TagInputController")

    page.execute_script(<<~JS, hostile_name)
      class Controller {}
      #{source}
      const list = document.createElement("div");
      list.id = "security-tag-suggestions";
      document.body.appendChild(list);
      const controller = new TagInputController();
      controller.listTarget = list;
      controller.renderResults([{id: 1, name: arguments[0]}], "");
    JS

    within "#security-tag-suggestions" do
      assert_selector "button", count: 1
      assert_no_selector "img, script"
      assert_equal hostile_name, find("button")["data-name"]
      assert_text hostile_name
    end
    assert_nil page.evaluate_script("window.tagInjected")
  end
end
