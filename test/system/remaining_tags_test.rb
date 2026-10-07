require "application_system_test_case"

class RemainingTagsTest < ApplicationSystemTestCase
  test "remaining tags expand inline on click in the feed and admin table" do
    admin = create_user(role: :admin)
    post = create_post(user: admin, verified: true)
    %w[alpha beta gamma delta].each { |name| post.tags << Tag.create!(name: name) }
    visit new_user_session_path(locale: :en)
    fill_in "Email", with: admin.email
    fill_in "Password", with: "secure-password-123"
    click_button "Sign in"
    assert_no_selector "#user_email"

    [ blog_path(locale: :en), admin_posts_path(locale: :en) ].each do |path|
      visit path
      featured_tag_class = path == blog_path(locale: :en) ? find_link("#alpha")[:class] : nil
      within '[data-controller="remaining-tags"]' do
        assert_no_link "#gamma"
        assert_no_link "#delta"
        click_button "+2"
        assert_link "#gamma"
        assert_link "#delta"
        assert_no_button "+2"
        if featured_tag_class
          %w[gamma delta].each do |name|
            tag = post.tags.find_by!(name: name)
            assert_link "##{name}", href: blog_path(locale: :en, tag_id: tag.id)
            assert_equal featured_tag_class, find_link("##{name}")[:class]
          end
        end
      end
    end
  end
end
