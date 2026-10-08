require "test_helper"

class SearchTest < ActionDispatch::IntegrationTest
  setup do
    @old_suffix = Searchkick.index_suffix
    Searchkick.index_suffix = "search_audit_#{Process.pid}"
    @post_index = Post.search_index
    @tag_index = Tag.search_index
    @post_index.create(@post_index.index_options)
    @tag_index.create(@tag_index.index_options)
    @user = create_user
  end

  teardown do
    @post_index.delete
    @tag_index.delete
    Searchkick.index_suffix = @old_suffix
  end

  def indexed_post(title:, tag: nil, body: "Neutral content")
    record = Post.create!(user: @user, title: title, body: body, status: :published, verified: true)
    record.tags << tag if tag
    PostSearchIndexJob.perform_now(record.id)
    @post_index.refresh
    record
  end

  def results(q)
    get posts_path(locale: :en), params: { q: q }, as: :json
    assert_response :success
    JSON.parse(response.body).fetch("posts")
  end

  test "ban hides indexed posts immediately and unban restores them without reindexing" do
    record = indexed_post(title: "Restrictionsearchneedle")
    assert_equal [ record.id ], results("Restrictionsearchneedle").map { |item| item["id"] }
    @user.update!(banned_at: Time.current)
    assert_empty results("Restrictionsearchneedle")
    @user.update!(banned_at: nil)
    assert_equal [ record.id ], results("Restrictionsearchneedle").map { |item| item["id"] }
    @user.update!(suspended_until: 1.day.from_now)
    assert_equal [ record.id ], results("Restrictionsearchneedle").map { |item| item["id"] }
  end

  test "tag filters exclude untagged title matches" do
    tag = Tag.create!(name: "quartzneedle")
    tagged = indexed_post(title: "Tagged entry", tag: tag)
    indexed_post(title: "quartzneedle title collision")
    get posts_path(locale: :en), params: { tag_id: tag.id }, as: :json
    assert_response :success
    assert_equal [ tagged.id ], JSON.parse(response.body).fetch("posts").map { |p| p["id"] }
  end

  test "partial tag searches use the configured word_middle index" do
    tag = Tag.create!(name: "quartzneedle")
    record = indexed_post(title: "Tagged entry", tag: tag)
    assert_equal [ record.id ], results("artznee").map { |p| p["id"] }
    assert_equal 1, results("quartzneedle").size
  end

  test "a stale index cannot expose a newly private post" do
    record = indexed_post(title: "visibilityneedle", body: "Private after withdrawal")
    record.update!(verified: false)
    found = results("visibilityneedle")
    assert_empty found
    assert_equal 0, JSON.parse(response.body).fetch("count")
    record.update!(status: :draft)
    assert_empty results("visibilityneedle")
  end

  test "body only edits schedule a search sync" do
    record = indexed_post(title: "Body entry")
    assert_enqueued_jobs 1, only: Searchkick::ReindexV2Job do
      record.update!(body: "freshbodyneedle")
    end
    PostSearchIndexJob.perform_now(record.id)
    @post_index.refresh
    assert_equal [ record.id ], results("freshbodyneedle").map { |p| p["id"] }
  end

  test "tag search outage falls back to matching database tags" do
    tag = Tag.create!(name: "quartzneedle")
    Tag.stub(:search, ->(*) { raise StandardError, "Audit simulated outage" }) do
      get tags_path(locale: :en), params: { q: "quartz" }, as: :json
    end
    assert_response :success
    assert_equal [ tag.id ], JSON.parse(response.body).map { |t| t["id"] }
  end

  test "post search outage returns an explicit unavailable response" do
    indexed_post(title: "quartzneedle")
    Post.stub(:search, ->(*) { raise StandardError, "Audit simulated outage" }) do
      get posts_path(locale: :en), params: { q: "quartzneedle" }, as: :json
      assert_response :service_unavailable
      assert JSON.parse(response.body).fetch("error").present?
      get blog_path(locale: :en), params: { q: "quartzneedle" }
      assert_response :service_unavailable
      assert_select '[role="alert"]', text: "Search is temporarily unavailable. Please try again."
      assert_select "div", text: /No results found/, count: 0
    end
  end

  test "tag add remove and rename reflect after processing index jobs" do
    tag = Tag.create!(name: "quartzneedle")
    record = indexed_post(title: "Tagged entry")
    record.tags << tag
    PostSearchIndexJob.perform_now(record.id)
    @post_index.refresh
    assert_equal [ record.id ], results("quartzneedle").map { |p| p["id"] }
    tag.update!(name: "renamedneedle")
    PostSearchIndexJob.perform_now(record.id)
    @post_index.refresh
    assert_empty results("quartzneedle")
    assert_equal [ record.id ], results("renamedneedle").map { |p| p["id"] }
    record.tag_ids = []
    record.save!
    PostSearchIndexJob.perform_now(record.id)
    @post_index.refresh
    assert_empty results("renamedneedle")
  end
  test "case insensitive tag search and tag autocomplete work" do
    tag = Tag.create!(name: "quartzneedle")
    record = indexed_post(title: "Tagged entry", tag: tag)
    tag.reindex(mode: :inline)
    @tag_index.refresh
    assert_equal [ record.id ], results("QUARTZNEEDLE").map { |p| p["id"] }
    get tags_path(locale: :en), params: { q: "QUARTZ" }, as: :json
    assert_response :success
    assert_equal [ tag.id.to_s ], JSON.parse(response.body).map { |t| t["id"].to_s }
  end

  test "fresh index excludes draft and unverified records" do
    visible = indexed_post(title: "visibilityneedle")
    hidden = indexed_post(title: "visibilityneedle hidden")
    hidden.update!(verified: false)
    draft = indexed_post(title: "visibilityneedle draft")
    draft.update!(status: :draft, verified: false)
    [ hidden, draft ].each { |p| PostSearchIndexJob.perform_now(p.id) }
    @post_index.refresh
    assert_equal [ visible.id ], results("visibilityneedle").map { |p| p["id"] }
  end

  test "title body and multiword tags are searchable" do
    tag = Tag.create!(name: "quartz needle")
    record = indexed_post(title: "titleneedle", tag: tag, body: "bodyneedle")
    [ "titleneedle", "bodyneedle", "quartz needle" ].each do |q|
      assert_equal [ record.id ], results(q).map { |p| p["id"] }
    end
  end

  test "stale hits do not inflate counts or leave empty pages" do
    6.times do |i|
      record = indexed_post(title: "paginationneedle #{i}")
      record.update!(verified: false) if i < 2
    end
    found = results("paginationneedle")
    assert_equal 4, found.size
    assert_equal 4, JSON.parse(response.body).fetch("count")
    assert found.all? { |p| p["verified"] }
  end

  test "tag filters survive pagination and combine with text queries" do
    tag = Tag.create!(name: "quartzneedle")
    5.times { |i| indexed_post(title: "paginationneedle #{i}", tag: tag) }
    indexed_post(title: "paginationneedle without tag")
    get blog_path(locale: :en), params: { q: "paginationneedle", tag_id: tag.id, page: 2 }, as: :json
    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal 5, payload.fetch("count")
    assert_equal 1, payload.fetch("posts").size
    get blog_path(locale: :en), params: { tag_id: tag.id }
    assert_response :success
    assert_select 'input[name="tag_id"][type="hidden"]', value: tag.id.to_s
    assert_select 'a[href*="page=2"][href*="tag_id="]'
  end

  test "dashboard searches treat percent and underscore literally" do
    indexed_post(title: "No wildcard here")
    record = indexed_post(title: "Literal %_ sequence")
    sign_in @user
    get mine_posts_path(locale: :en), params: { q: "%_" }
    assert_response :success
    assert_select "a", text: record.title
    assert_select "a", text: "No wildcard here", count: 0
  end
  test "admin rename merge and delete keep post tag search current" do
    source = Tag.create!(name: "quartzneedle")
    target = Tag.create!(name: "rubyneedle")
    record = indexed_post(title: "Tagged entry", tag: source)
    sign_in create_user(role: :admin)
    perform_enqueued_jobs only: Searchkick::ReindexV2Job do
      patch admin_tag_path(source, locale: :en), params: { tag: { name: "renamedneedle" } }
    end
    assert_response :see_other
    @post_index.refresh
    assert_empty results("quartzneedle")
    assert_equal [ record.id ], results("renamedneedle").map { |p| p["id"] }
    perform_enqueued_jobs only: PostSearchIndexJob do
      post merge_admin_tag_path(source, locale: :en), params: { target_name: target.name }
    end
    assert_response :see_other
    @post_index.refresh
    assert_empty results("renamedneedle")
    assert_equal [ record.id ], results("rubyneedle").map { |p| p["id"] }
    perform_enqueued_jobs only: PostSearchIndexJob do
      delete admin_tag_path(target, locale: :en)
    end
    assert_response :see_other
    @post_index.refresh
    assert_empty results("rubyneedle")
  end
end
