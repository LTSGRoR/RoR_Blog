class PublicPostSearch
  def initialize(query:, scope:)
    @query = query
    @scope = scope
  end

  def results
    # Reconcile ranked index hits with current database visibility before
    # counting or paginating. Filtering only the loaded page leaves stale
    # totals and empty pages when a post has just been withdrawn.
    ids = []
    hits = Post.search(
      @query,
      fields: [ { "title^5" => :word_middle }, { "tags^3" => :word_middle }, "body" ],
      where: { status: "published", verified: true },
      operator: @query.include?(" ") ? "and" : "or",
      misspellings: { below: 5 },
      load: false, limit: 500, scroll: "1m"
    )
    hits.scroll { |batch| ids.concat(batch.map { |hit| hit.id.to_i }) }
    @scope.in_order_of(:id, ids.uniq)
  ensure
    hits&.clear_scroll if hits&.scroll_id
  end
end
