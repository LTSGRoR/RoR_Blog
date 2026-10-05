require "test_helper"

class AdminSearchLocalizationTest < ActionDispatch::IntegrationTest
  setup do
    sign_in create_user(role: :admin)
  end

  test "post search labels options and clear links use each supported locale" do
    %i[en vi ja].each do |locale|
      translate = ->(key) { I18n.t("admin.posts.index.search_fields.#{key}", locale: locale, raise: true) }
      get admin_posts_path(locale: locale), params: { q: "sample", search_field: "tags", scope: "posts", filter: "all_posts" }
      assert_response :success
      assert_select 'label[for="search_field"]', text: translate.call("label")
      assert_select 'label[for="q"]', text: translate.call("query_label")
      assert_select 'input[name="q"]', placeholder: translate.call("placeholder")
      %w[all title author tags].each do |field|
        assert_select "select[name=search_field] option[value=#{field}]", text: translate.call(field)
      end
      assert_select "a", text: translate.call("clear") do |links|
        assert_equal admin_posts_path(locale: locale, scope: "posts", filter: "all_posts", search_field: "tags"), links.first["href"]
      end
    end
  end

  test "user role and status controls have translated accessible labels and options" do
    %i[en vi ja].each do |locale|
      translate = ->(key) { I18n.t("users.admin.index.#{key}", locale: locale, raise: true) }
      get users_path(locale: locale)
      assert_response :success
      assert_select 'input[name="q"]', placeholder: translate.call("search_placeholder")
      assert_select 'select[name="role"]' do
        assert_select "[aria-label=?]", translate.call("columns.role")
        { "" => "filters.role.any", "admin" => "filters.role.admin", "author" => "filters.role.author" }.each do |value, key|
          assert_select "option[value=?]", value, text: translate.call(key)
        end
      end
      assert_select 'select[name="status"][aria-label=?]', translate.call("columns.status")
      { "" => "filters.status.any", "active" => "status.active", "banned" => "status.banned", "suspended" => "filters.status.suspended" }.each do |value, key|
        assert_select 'select[name="status"] option[value=?]', value, text: translate.call(key)
      end
    end
  end
end
