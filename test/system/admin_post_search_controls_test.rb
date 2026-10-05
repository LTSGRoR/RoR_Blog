require "application_system_test_case"

class AdminPostSearchControlsTest < ApplicationSystemTestCase
  test "search controls work on mobile and retain field when cleared" do
    admin = create_user(role: :admin)
    post = create_post(user: admin, verified: true)
    post.tags << Tag.create!(name: "uxneedle")
    visit new_user_session_path(locale: :en)
    fill_in "Email", with: admin.email
    fill_in "Password", with: "secure-password-123"
    click_button "Sign in"
    assert_no_selector "#user_email"
    page.current_window.resize_to(390, 844)
    visit admin_posts_path(locale: :en, scope: "posts", filter: "all_posts")
    select "Tags", from: "Search in"
    fill_in "Search query", with: "uxneedle"
    within 'form[role="search"]' do
      click_button "Search"
    end
    assert_link post.title
    assert_select "Search in", selected: "Tags"
    assert page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('form[role="search"] select, form[role="search"] input:not([type="hidden"]), form[role="search"] a')).every(element => {
        const box = element.getBoundingClientRect();
        return box.left >= 0 && box.right <= window.innerWidth && box.height >= 44;
      })
    JS
    click_link "Clear search"
    assert_field "Search query", with: ""
    assert_select "Search in", selected: "Tags"
    assert_no_link "Clear search"
  ensure
    page.current_window.resize_to(1400, 1000)
  end
end
