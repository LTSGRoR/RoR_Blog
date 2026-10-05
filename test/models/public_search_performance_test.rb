require "test_helper"

class PublicSearchPerformanceTest < ActiveSupport::TestCase
  test "search uses a bounded window and still rechecks visibility" do
    public_post = create_post(user: create_user, verified: true)
    private_post = create_post(user: public_post.user)
    hits = [ public_post, private_post ]
    hits.define_singleton_method(:total_count) { PublicPostSearch::RESULT_LIMIT + 1 }
    search = PublicPostSearch.new(query: "test", scope: Post.where(verified: true, status: :published))
    Post.stub(:search, lambda { |query, **options|
      assert_equal "test", query
      assert_equal PublicPostSearch::RESULT_LIMIT, options[:limit]
      assert_not options.key?(:scroll)
      hits
    }) do
      assert_equal [ public_post.id ], search.results.pluck(:id)
      assert search.limited
    end
  end
end
