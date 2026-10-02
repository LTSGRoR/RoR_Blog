require "application_system_test_case"

class TagSuggestionsTest < ApplicationSystemTestCase
  test "a new post can create AI despite an API suggestion" do
    user = create_user
    api = Tag.create!(name: "api")
    visit new_user_session_path(locale: :en)
    fill_in "Email", with: user.email
    fill_in "Password", with: "secure-password-123"
    click_button "Sign in"
    assert_no_selector "#user_email"

    Tag.stub(:search, ->(*) { [ api ] }) do
      visit new_post_path(locale: :en)
      input = find('[data-tag-input-target="input"]')
      input.set("AI")
      assert_selector "[data-tag-option]", text: 'Create tag "AI"'
      assert_selector "[data-tag-option]", text: "api"
      input.send_keys(:enter)
      assert_selector '[data-tag-input-target="chips"] span', text: "ai"
      assert_no_selector '[data-tag-input-target="chips"] span', text: "api"
      assert Tag.exists?(name: "ai")

      input.set("ML")
      find("[data-tag-option]", text: 'Create tag "ML"').click
      assert_selector '[data-tag-input-target="chips"] span', text: "ml"
      assert Tag.exists?(name: "ml")

      input.set("AP")
      assert_selector '[data-tag-option][data-name="api"]'
      input.send_keys(:arrow_down, :enter)
      assert_selector '[data-tag-input-target="chips"] span', text: "api"
      assert_not Tag.exists?(name: "ap")
    end
  end

  test "clicking a suggested tag does not also create the typed prefix" do
    user = create_user
    api = Tag.create!(name: "api")
    visit new_user_session_path(locale: :en)
    fill_in "Email", with: user.email
    fill_in "Password", with: "secure-password-123"
    click_button "Sign in"
    assert_no_selector "#user_email"

    Tag.stub(:search, ->(*) { [ api ] }) do
      visit new_post_path(locale: :en)
      find('[data-tag-input-target="input"]').set("AP")
      find('[data-tag-option][data-name="api"]').click
      assert_selector '[data-tag-input-target="chips"] span', text: "api"
      assert_no_selector '[data-tag-input-target="chips"] span', text: "ap", exact_text: true
      assert_not Tag.exists?(name: "ap")
    end
  end

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
