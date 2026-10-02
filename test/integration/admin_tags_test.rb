require "test_helper"

class AdminTagsTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_user(role: :admin)
    @author = create_user
    @tag = Tag.create!(name: "ai")
    @post = create_post(user: @author, verified: true)
    @post.tags << @tag
    @revision = create_revision(post: @post)
    @revision.tags << @tag
  end

  test "authors cannot access any tag management action" do
    sign_in @author
    get admin_tags_path(locale: :en), as: :json
    assert_response :forbidden
    get search_admin_tags_path(locale: :en), params: { q: "ai" }, as: :json
    assert_response :forbidden
    get edit_admin_tag_path(@tag, locale: :en), as: :json
    assert_response :forbidden
    patch admin_tag_path(@tag, locale: :en), params: { tag: { name: "changed" } }, as: :json
    assert_response :forbidden
    post merge_admin_tag_path(@tag, locale: :en), params: { target_name: "other" }, as: :json
    assert_response :forbidden
    delete admin_tag_path(@tag, locale: :en), as: :json
    assert_response :forbidden
    assert_equal "ai", @tag.reload.name
  end

  test "anonymous visitors must sign in" do
    get admin_tags_path(locale: :en)
    assert_redirected_to new_user_session_path(locale: :en)
  end

  test "index displays counts and searches literal tag names" do
    sign_in @admin
    Tag.create!(name: "unused")
    get admin_tags_path(locale: :en)
    assert_response :success
    assert_select "h1", text: "Manage Tags"
    assert_select "a[href=?] svg", admin_tags_path(locale: :en)
    assert_select "tr", text: /#ai\s+1\s+1/
    get admin_tags_path(locale: :en), params: { filter: "unused" }
    assert_select "a", text: "#unused"
    assert_select "a", text: "#ai", count: 0
    get admin_tags_path(locale: :en), params: { q: "%" }
    assert_select "tbody tr", count: 0
  end

  test "rename normalizes and schedules post reindexing" do
    sign_in @admin
    assert_enqueued_jobs 1, only: Searchkick::ReindexV2Job do
      patch admin_tag_path(@tag, locale: :en), params: { tag: { name: " Artificial Intelligence " } }
    end
    assert_redirected_to admin_tags_path(locale: :en)
    assert_equal "artificial intelligence", @tag.reload.name
  end

  test "duplicate or empty rename shows validation errors" do
    sign_in @admin
    Tag.create!(name: "api")
    [ " API ", " " ].each do |name|
      patch admin_tag_path(@tag, locale: :en), params: { tag: { name: name } }
      assert_response :unprocessable_entity
      assert_select '[role="alert"]'
      assert_select "h1", text: "Manage #ai"
      assert_equal "ai", @tag.reload.name
    end
  end

  test "merge moves post and revision tags without duplicates" do
    sign_in @admin
    target = Tag.create!(name: "artificial intelligence")
    @post.tags << target
    @revision.tags << target
    other = create_post(user: @author)
    other.tags << @tag
    old_version = @revision.reload.lock_version
    assert_enqueued_with(job: PostSearchIndexJob, args: [ @post.id ]) do
      post merge_admin_tag_path(@tag, locale: :en), params: { target_name: " ARTIFICIAL INTELLIGENCE " }
    end
    assert_redirected_to admin_tags_path(locale: :en)
    assert_not Tag.exists?(@tag.id)
    assert_equal [ target.id ], @post.reload.tag_ids
    assert_equal [ target.id ], @revision.reload.tag_ids
    assert_equal [ target.id ], other.reload.tag_ids
    assert_operator @revision.lock_version, :>, old_version
    assert @post.verified?
  end

  test "invalid merge targets keep associations intact" do
    sign_in @admin
    [ "ai", "missing", "" ].each do |name|
      post merge_admin_tag_path(@tag, locale: :en), params: { target_name: name }
      assert_response :unprocessable_entity
      assert_equal [ @tag.id ], @post.reload.tag_ids
      assert_equal [ @tag.id ], @revision.reload.tag_ids
    end
  end

  test "merge rolls back associations if a write fails" do
    target = Tag.create!(name: "target")
    PostRevisionTagging.stub(:find_or_create_by!, ->(*) { raise ActiveRecord::RecordInvalid.new(@revision) }) do
      assert_raises(ActiveRecord::RecordInvalid) { MergeTags.call(source: @tag, target: target) }
    end
    assert Tag.exists?(@tag.id)
    assert_equal [ @tag.id ], @post.reload.tag_ids
    assert_equal [ @tag.id ], @revision.reload.tag_ids
  end

  test "edit lists affected content and deletion preserves content" do
    sign_in @admin
    get edit_admin_tag_path(@tag, locale: :en)
    assert_response :success
    assert_select "a", text: @post.title
    assert_select "a", text: @revision.title
    assert_select "form[data-turbo-confirm]", count: 1
    assert_select 'input[type="submit"][data-turbo-confirm]', count: 1
    assert_enqueued_with(job: PostSearchIndexJob, args: [ @post.id ]) do
      delete admin_tag_path(@tag, locale: :en)
    end
    assert_redirected_to admin_tags_path(locale: :en)
    assert_not Tag.exists?(@tag.id)
    assert @post.reload.persisted?
    assert @revision.reload.persisted?
    assert_empty @post.tag_ids
    assert_empty @revision.tag_ids
  end
  test "merge search finds partial names excludes source and escapes wildcards" do
    sign_in @admin
    api = Tag.create!(name: "api")
    get search_admin_tags_path(locale: :en), params: { q: "I", exclude_id: @tag.id }, as: :json
    assert_response :success
    assert_equal [ api.id ], JSON.parse(response.body).map { |tag| tag["id"] }
    get search_admin_tags_path(locale: :en), params: { q: "%", exclude_id: @tag.id }, as: :json
    assert_equal [], JSON.parse(response.body)
    get search_admin_tags_path(locale: :en), params: { exclude_id: @tag.id }, as: :json
    assert_equal [], JSON.parse(response.body)
  end
end
