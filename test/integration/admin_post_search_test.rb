require "test_helper"

class AdminPostSearchTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_user(role: :admin)
    @author = create_user
    @author.update!(name: "Needle Author")
    @post = create_post(user: @author, verified: true)
    @post.update!(title: "Parent title")
    @revision = create_revision(post: @post)
    @revision.update!(title: "Unique revision title")
    sign_in @admin
  end

  def search(q, scope: "posts", **params)
    get admin_posts_path(locale: :en), params: { q: q, scope: scope }.merge(params)
    assert_response :success
  end

  test "revision title and parent title both match" do
    search("Unique revision", scope: "revisions")
    assert_select "a[href=?]", admin_post_revision_path(@revision, locale: :en), minimum: 1
    search("Parent title", scope: "revisions")
    assert_select "a[href=?]", admin_post_revision_path(@revision, locale: :en), minimum: 1
  end

  test "SQL wildcard characters match literally" do
    [ "%", "_" ].each do |query|
      search(query)
      assert_select "a[href=?]", post_path(@post, locale: :en), count: 0
      search(query, scope: "revisions")
      assert_select "a[href=?]", admin_post_revision_path(@revision, locale: :en), count: 0
    end
  end

  test "post and revision tags are searched" do
    tag = Tag.create!(name: "quartzneedle")
    @post.tags << tag
    @revision.tags << tag
    search(tag.name)
    assert_select "a[href=?]", post_path(@post, locale: :en), minimum: 1
    search(tag.name, scope: "revisions")
    assert_select "a[href=?]", admin_post_revision_path(@revision, locale: :en), minimum: 1
  end

  test "case insensitive partial title author and email work" do
    [ "PARENT", "Needle", @author.email ].each do |query|
      search(query)
      assert_select "a[href=?]", post_path(@post, locale: :en), minimum: 1
    end
    [ "Needle", @author.email ].each do |query|
      search(query, scope: "revisions")
      assert_select "a[href=?]", admin_post_revision_path(@revision, locale: :en), minimum: 1
    end
  end

  test "search retains filter and pagination context" do
    10.times { create_post(user: @author) }
    search("Needle", filter: "all_posts")
    assert_select 'a[href*="posts_page=2"][href*="q=Needle"][href*="scope=posts"][href*="filter=all_posts"]'
    search("Needle", filter: "all_posts", posts_page: 2)
    assert_select "tbody tr td:first-child a", count: 1
    search("Needle", filter: "awaiting_review")
    assert_select "a[href=?]", post_path(@post, locale: :en), count: 0
    search("Needle", scope: "revisions", filter: "open")
    assert_select "a[href=?]", admin_post_revision_path(@revision, locale: :en), count: 0
  end

  test "author cannot access search and anonymous visitors must sign in" do
    sign_out @admin
    sign_in @author
    get admin_posts_path(locale: :en), params: { q: "Parent" }, as: :json
    assert_response :forbidden
    sign_out @author
    get admin_posts_path(locale: :en), params: { q: "Parent" }
    assert_redirected_to new_user_session_path(locale: :en)
  end
  test "literal wildcard characters find titles containing those characters" do
    @post.update!(title: "Literal %_ title")
    @revision.update!(title: "Literal %_ revision")
    search("%_")
    assert_select "a[href=?]", post_path(@post, locale: :en), minimum: 1
    search("%_", scope: "revisions")
    assert_select "a[href=?]", admin_post_revision_path(@revision, locale: :en), minimum: 1
  end

  test "multiple matching tags do not duplicate rows and revision tags are independent" do
    first = Tag.create!(name: "needle-one")
    second = Tag.create!(name: "needle-two")
    @post.tags << [ first, second ]
    search("needle-", scope: "posts")
    assert_select "tbody tr td:first-child a", count: 1
    search("needle-", scope: "revisions")
    assert_select "tbody tr td:first-child a", count: 0
    @revision.tags << [ first, second ]
    search("NEEDLE-", scope: "revisions")
    assert_select "tbody tr td:first-child a", count: 1
    search("needle-", filter: "awaiting_review")
    assert_select "tbody tr td:first-child a", count: 0
  end
  test "space separated queries find existing hyphenated machine learning tags" do
    @post.update!(title: "Intro to Machine Learning with Ruby")
    tagged = create_post(user: @author, verified: true)
    tagged.update!(title: "Anime AI Done Right")
    tag = Tag.create!(name: "machine-learning")
    tagged.tags << tag
    @revision.tags << tag
    [ "machine learning", "MACHINE   LEARNING", "machine-learning" ].each do |query|
      search(query)
      assert_select "a[href=?]", post_path(tagged, locale: :en), minimum: 1
      search(query, scope: "revisions")
      assert_select "a[href=?]", admin_post_revision_path(@revision, locale: :en), minimum: 1
    end
    search("machine learning")
    assert_select "a[href=?]", post_path(@post, locale: :en), minimum: 1
    assert_select "tbody tr td:first-child a", count: 2
  end
end
