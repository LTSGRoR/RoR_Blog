require "application_system_test_case"

class AdminTagsSystemTest < ApplicationSystemTestCase
  test "admin can search rename and merge tags using management pages" do
    admin = create_user(role: :admin)
    Tag.create!(name: "ai")
    Tag.create!(name: "api")
    Tag.create!(name: "unused")
    visit new_user_session_path(locale: :en)
    fill_in "Email", with: admin.email
    fill_in "Password", with: "secure-password-123"
    click_button "Sign in"
    assert_no_selector "#user_email"

    visit admin_posts_path(locale: :en)
    click_link "Manage Tags", match: :first
    assert_selector "h1", text: "Manage Tags"
    assert_selector "tbody tr", count: 3
    page.save_screenshot("/tmp/ror-admin-tags-desktop.png")
    page.driver.browser.manage.window.resize_to(390, 844)
    page.save_screenshot("/tmp/ror-admin-tags-mobile.png")
    page.driver.browser.manage.window.resize_to(1200, 900)

    fill_in "Search tag names", with: "ai"
    click_button "Search"
    assert_selector "tbody tr", count: 1
    click_link "#ai"
    fill_in "Tag name", with: "artificial intelligence"
    click_button "Rename tag"
    assert_selector "h1", text: "Manage Tags"
    assert_text "Tag renamed."
    click_link "#artificial intelligence"
    6.times { |i| Tag.create!(name: "api-#{i}") }
    find_field("Existing destination tag name").click
    assert_no_selector '[data-tag-merge-target="results"] button'
    fill_in "Existing destination tag name", with: "i"
    assert_selector '[data-tag-merge-target="results"] button', count: 7
    dimensions = page.evaluate_script(<<~JS)
      (() => {
        const list = document.querySelector('[data-tag-merge-target="results"]');
        const row = list.querySelector('button');
        return [list.clientHeight, list.scrollHeight, row.offsetHeight];
      })()
    JS
    assert_equal 5 * dimensions[2], dimensions[0]
    assert_operator dimensions[1], :>, dimensions[0]
    fill_in "Existing destination tag name", with: ""
    assert_no_selector '[data-tag-merge-target="results"] button'
    fill_in "Existing destination tag name", with: "i"
    within '[data-tag-merge-target="results"]' do
      assert_button "#api"
      assert_no_button "#artificial intelligence"
      click_button "#api"
    end
    assert_field "Existing destination tag name", with: "api"
    assert_no_selector '[role="dialog"]'
    click_button "Merge tag"
    click_button "Confirm"
    assert_selector "h1", text: "Manage Tags"
    assert_text "Tags merged."
    assert_not Tag.exists?(name: "artificial intelligence")
    assert Tag.exists?(name: "api")
  end
end
