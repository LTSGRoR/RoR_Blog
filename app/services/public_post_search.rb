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
    # Enforce account visibility immediately, even before async index updates.
    banned_ids = User.where.not(banned_at: nil).pluck(:id)
    filters[:user_id] = { not: banned_ids } if banned_ids.any?
    filters[:tags] = @tag.name if @tag
    hits = Post.search(
      @query,
      fields: [ { "title^5" => :word_middle }, { "tags^3" => :word_middle }, "body" ],
      where: filters,
      operator: @query.include?(" ") ? "and" : "or",
      misspellings: { below: 5 },
      # The database supplies the cards; avoid transferring indexed bodies.
      select: [], load: false, limit: RESULT_LIMIT
    )
    @limited = hits.total_count > RESULT_LIMIT
    ids = hits.map { |hit| hit.id.to_i }
    @scope.publicly_visible.in_order_of(:id, ids.uniq)
  end
end
