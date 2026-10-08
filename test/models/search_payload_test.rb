ENV["RAILS_ENV"] ||= "test"
ENV["EMBEDDINGS_AUTO_RUN_ON_BOOT"] = "false"
require_relative "../../config/environment"
require "active_support/test_case"
require "minitest/autorun"
require "minitest/mock"

class SearchPayloadTest < ActiveSupport::TestCase
  test "ID-only Searchkick hits preserve rank and the bounded visibility check" do
    hits = Searchkick::Results.new(Post, { "hits" => {
      "total" => { "value" => 1001 },
      "hits" => [ { "_id" => "9" }, { "_id" => "4" } ]
    } }, load: false)
    bans = Object.new
    bans.define_singleton_method(:not) { |**| self }
    bans.define_singleton_method(:pluck) { |_| [] }
    scope = Object.new
    scope.define_singleton_method(:publicly_visible) { self }
    scope.define_singleton_method(:in_order_of) { |field, ids| [field, ids] }
    search = PublicPostSearch.new(query: "ruby", scope: scope)
    capture = ->(query, **options) do
      assert_equal "ruby", query
      assert_equal [], options[:select]
      assert_equal 1000, options[:limit]
      assert_equal false, options[:load]
      hits
    end
    User.stub(:where, bans) do
      Post.stub(:search, capture) { assert_equal [:id, [9, 4]], search.results }
    end
    assert search.limited
  end

  test "Searchkick translates empty selection into disabled source retrieval" do
    query = Searchkick::Query.new(Post, "ruby", load: false, select: [])
    assert_equal false, query.body[:_source]
  end
end
