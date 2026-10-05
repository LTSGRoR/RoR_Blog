class PublicPostSearch
  RESULT_LIMIT = 1_000
  attr_reader :limited

  def initialize(query:, scope:, tag: nil)
    @query = query
    @scope = scope
    @tag = tag
  end

  def results
    filters = { status: "published", verified: true }
    filters[:tags] = @tag.name if @tag
    hits = Post.search(
      @query,
      fields: [ { "title^5" => :word_middle }, { "tags^3" => :word_middle }, "body" ],
      where: filters,
      operator: @query.include?(" ") ? "and" : "or",
      misspellings: { below: 5 },
      load: false, limit: RESULT_LIMIT
    )
    @limited = hits.total_count > RESULT_LIMIT
    ids = hits.map { |hit| hit.id.to_i }
    @scope.in_order_of(:id, ids.uniq)
  end
end
