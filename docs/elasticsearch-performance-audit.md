# Elasticsearch performance audit — 2026-10-08

This source audit covers public post search, tag autocomplete, model callbacks, index jobs, bulk imports, and worker/boot configuration. No live Elasticsearch latency or production load measurements were taken.

## Improvements made

- Public search now requests IDs only (`select: []`, which Searchkick translates to `_source: false`). Previously each query could transfer 1,000 complete indexed documents, including article bodies, even though PostgreSQL renders the cards. The result window, relevance ordering, tag filters, and database visibility checks are preserved.
- Added `Post.search_import` to preload tags and ActionText bodies during Searchkick imports. Bulk document generation previously risked one tag query and one rich-text query per post. Added a database regression test requiring document generation to issue no additional queries after preloading.

## Remaining costs, in priority order

1. **Search indexing could be starved by embeddings.** The subsequent Docker architecture audit changed development/production Compose and Kamal commands to weighted queues (`-q searchkick,2 -q embeddings,1`), giving both queues opportunities to run. This is probabilistic fairness, not reserved worker capacity; long embeddings jobs can still occupy both threads. Use separate workers if strict search latency is required. Measure queue latency, not just queue length. No running workers were restarted.
2. **Pagination repeats the bounded search window.** Every text-search page retrieves up to 1,000 IDs and PostgreSQL builds a CASE expression to restore relevance before pagination. This is bounded but expensive compared with requesting a single Elasticsearch page. Direct Elasticsearch pagination is not a drop-in replacement: stale hits must still be filtered without creating empty pages or inaccurate counts. Measure first, then design cursor/overfetch pagination if traffic justifies it.
3. **Tag edits can enqueue many redundant index jobs.** A rename traverses all related posts and enqueues each on the HTTP request's path. Tagging changes, rich-text changes, and searchable post changes can also enqueue the same post more than once. Move large rename fan-out to a batch job and consider per-post coalescing with guaranteed requeue after concurrent changes. Do not discard duplicates blindly: a later edit must still be indexed.
4. **Every search loads all banned author IDs.** This adds a PostgreSQL query and a potentially large Elasticsearch exclusion filter. Retain the final PostgreSQL visibility check for correctness; consider a denormalized author-visibility field with reliable ban/unban index updates if the banned population grows. Caching exclusions without invalidation can also consume the result window with hidden hits.
5. **Substring indexing and fuzzy retries have costs.** `word_middle` on titles/tags increases index size; low-result searches may issue a misspelling retry. Tag autocomplete is bounded to 20 hits but fuzzy search may be unnecessary for a rapidly updating picker. Change these only after measuring relevance and request rate.
6. **Full reindex on boot is expensive.** Keep `REINDEX_ON_BOOT=false` for normal production startup. Run full rebuilds as planned maintenance after mapping changes, rather than on every app restart.

## Existing behavior worth preserving

Public search has a 1,000-hit cap, uses ID-only ORM loading rather than loading every hit as a record, and rechecks public visibility in PostgreSQL. Search failures return an explicit unavailable response instead of silently scanning all article bodies in SQL. Tag autocomplete has a bounded database prefix fallback. Non-searchable moderation metadata updates avoid post reindex callbacks; indexing runs on the dedicated searchkick queue. Missing-post jobs remove stale documents.

## Validation and next measurements

The no-database tests in `test/models/search_payload_test.rb` verify source suppression through Searchkick's actual query builder and ranking/visibility handoff with source-free hits. The database import query-count test is in `test/models/public_search_performance_test.rb`; it could not run because Docker is unavailable locally.

Before further tuning, record search p50/p95 latency, Elasticsearch response bytes and `took`, SQL time/query counts, searchkick queue latency, index size, and a representative full-reindex duration. Compare common queries, rare queries that trigger fuzzy retries, deep pages, and tag renames. No production services, index mappings, or documents were changed.
