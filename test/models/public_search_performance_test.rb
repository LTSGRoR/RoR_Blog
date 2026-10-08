require "test_helper"

class PublicSearchPerformanceTest < ActiveSupport::TestCase
  test "bulk search document generation preloads tags and rich text" do
    3.times { create_post(user: create_user, verified: true) }
    posts = Post.search_import.to_a
    queries = []
    capture = ->(_name, _start, _finish, _id, payload) do
      queries << payload[:sql] unless payload[:name] == "SCHEMA" || payload[:cached]
    end
    ActiveSupport::Notifications.subscribed(capture, "sql.active_record") do
      posts.each(&:search_data)
    end
    assert_empty queries, "Search document generation must use preloaded associations"
  end

  test "search uses a bounded window and still rechecks visibility" do
    public_post = create_post(user: create_user, verified: true)
    private_post = create_post(user: public_post.user)
    hits = [ public_post, private_post ]
    hits.define_singleton_method(:total_count) { PublicPostSearch::RESULT_LIMIT + 1 }
    search = PublicPostSearch.new(query: "test", scope: Post.where(verified: true, status: :published))
    Post.stub(:search, lambda { |query, **options|
      assert_equal "test", query
      assert_equal PublicPostSearch::RESULT_LIMIT, options[:limit]
      assert_equal [], options[:select]
      assert_not options.key?(:scroll)
      hits
    }) do
      assert_equal [ public_post.id ], search.results.pluck(:id)
      assert search.limited
    end
  end
end
