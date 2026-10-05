# Performance audit — 2026-10-02

## Scope and evidence

Reviewed public/admin search, feed rendering, chat history and polling, indexing jobs, database indexes, and Docker worker configuration. Ran read-only authenticated integration requests inside the local development Docker app; no application data changes or AI provider calls were made. This is a code and local request audit, not a production load test or browser performance benchmark.

Dataset: 17 posts, 33 tags, 14 chat histories; the measured admin has one history. Each route received two requests; the second request is shown below. SQL counts exclude cached queries, schema queries, and transaction events.

| Request | HTTP | Second-request time | Uncached SQL calls |
| --- | --- | --- | --- |
| `/en/blog` | 200 | 49.2 ms | 19 |
| `/en/blog?q=machine learning` | 200 | 57.2 ms | 17 |
| `/en/admin/posts?q=machine learning` | 200 | 29.0 ms | 6 |

First-request times were 297.7, 253.7, and 52.0 ms respectively. These samples demonstrate working requests on a small dataset; they do not establish production latency percentiles or capacity. A trailing dataset count in the initial request harness failed after Rails request context cleanup; counts were obtained successfully in a separate runner. That harness exception is not an application finding.

## Findings

### 1. High: public search retrieves all hits before pagination

Evidence: `app/services/public_post_search.rb:18–23` scrolls through every Elasticsearch result in batches of 500, collects every ID in Ruby, and builds `in_order_of(:id, ids.uniq)` on the database relation. Work and SQL size grow with the total number of matching posts, even when displaying only the first page. Repeated live searches multiply this cost.

Recommended change: retrieve a bounded search window and paginate that window, rechecking database publication/verification permissions before returning results. Define how totals and further pages behave when indexed records are stale. Preserve current visibility protections; simply trusting Elasticsearch results would regress correctness. Validate with thousands of broad matches, stale index entries, and first/subsequent pages.

### 2. High scaling risk: hidden chat history renders on every signed-in page

Evidence: `app/views/layouts/application.html.erb:227` includes the chat modal globally. `app/views/shared/_ai_chat_modal.html.erb:37` loads up to 50 histories before the user opens it. Each eligible history invokes `suggested_posts(limit: 3)` in `app/views/chat_histories/_chat_history_item.html.erb:12`; `app/models/chat_history.rb:45` queries visible posts and loads their users/tags separately for that history.

This makes ordinary navigation pay for hidden chat content and repeated suggestion queries. The measured admin has only one history, so current request timings do not represent the upper bound.

Recommended change: load history on first open, paginate older messages, and fetch suggested posts for a page of histories in one batch with shared preloads. Verify query count with 50 completed histories containing suggestions and confirm visibility is still enforced.

### 3. Medium: feed panels are recomputed for each search; author avatars lack preloading

Evidence: `app/controllers/posts_controller.rb:14,202` loads most-read posts, trending tags, and top authors on each index request. Ranking uses per-post comment/reaction subqueries; trending tags and authors aggregate published posts. These costs increase with dataset size and repeat during live search. `app/views/posts/index.html.erb` accesses top-author avatar attachments without preloading them in `@top_authors`.

Both measured feed requests issued seven uncached attachment-load queries. Main feed associations already have preloads; sidebar author avatars are a concrete remaining source of per-author lookups. Most-read comment rendering uses the existing counter cache and is not classified as a comment N+1.

Recommended change: preload top-author avatar attachments/blobs, and cache shared sidebar data with bounded expiration and appropriate publication-change invalidation. Consider maintaining ranking counters if representative query plans show aggregate scans dominate. Avoid rebuilding the sidebar during results-only live search updates.

### 4. Medium: embedding persistence schedules an unnecessary follow-up job

Evidence: `app/models/post.rb:199` considers any `updated_at` change relevant to embeddings. `app/jobs/index_post_embeddings_job.rb:15` saves the embedding and digest with `update!`, which changes `updated_at` and runs the same after-commit enqueue path. Ordinary metadata updates can enqueue jobs too.

The digest guard prevents a second provider request once the vector is current, so this is extra queue/database work, not an infinite generation loop. Concurrent jobs can still pass the digest check before either stores its result; no per-post generation lock is visible in this path.

Recommended change: schedule only when embedding source content changes, persist computed vectors without rescheduling, and coalesce concurrent work per post. Preserve body-edit scheduling, including Action Text changes. Validate that one source edit results in one provider call and storing a vector does not enqueue another embedding job.

### 5. Medium scaling risk: admin substring search lacks matching text indexes

Evidence: `app/controllers/admin/posts_controller.rb:28,79` uses substring `ILIKE` and normalizes tag separators with `regexp_replace`. `db/schema.rb` has ordinary name/email indexes but no trigram indexes matching these predicates. Ordinary indexes do not provide the same substring-search access path, and tag normalization adds per-candidate work.

The measured admin search is fast on 17 posts; no large-dataset slowdown is claimed. Recommended change: capture `EXPLAIN (ANALYZE, BUFFERS)` on representative data, then add appropriate trigram indexes and a matching normalized tag expression or stored column where warranted. Keep title/author/tag matching behavior and wildcard escaping intact.

### 6. Medium concurrency risk: all chat submissions share one transaction lock

Evidence: `app/models/chat_history.rb:18` acquires a fixed PostgreSQL advisory transaction lock before checking limits and creating a request. This intentionally protects quota consistency but serializes acceptance across users.

Recommended change: measure concurrent submission wait time first. If significant, use per-user serialization plus an atomic global daily quota reservation. Retain quota guarantees; removing the lock alone would allow races. No concurrent load measurement was performed in this audit.

### 7. Medium operational risk: interactive AI and indexing share worker capacity

Evidence: `docker-compose.yml:87` and `config/deploy.yml:14` run one Sidekiq process consuming `default` and `searchkick`. Embedding jobs use `default`, alongside interactive AI work. Slow provider calls and bulk indexing therefore compete for available workers.

Recommended change: separate interactive AI, embedding, and search indexing capacity where workload warrants it, with database connection pools sized for combined concurrency. Measure queue wait separately from provider time before tuning thread counts.

## Existing protections

- Chat polling has cancellation, bounded duration, and overlap protection; the previously reported endless polling behavior has been addressed in the current code. Pending requests still produce periodic HTTP traffic, so backoff or a lightweight pending response is a later optimization.
- Main feed associations are preloaded; post comment counts have a counter cache.
- Embedding source digests avoid repeat provider calls for unchanged content.
- Feed/visibility, chat timestamp, tagging, and vector indexes already exist. This audit does not claim vector indexes are missing.

## Recommended order

1. Lazy-load/batch chat history and preload sidebar avatars: focused changes with immediate query/render savings.
2. Remove redundant embedding scheduling and coalesce concurrent jobs.
3. Bound public search retrieval while preserving visibility and pagination correctness.
4. Measure representative search/aggregate query plans, then add targeted indexes and sidebar caching.
5. Load-test concurrent chat acceptance and queue wait before changing lock/worker architecture.

## Fixes implemented after the audit

All seven findings have implementation changes:

- Public search retrieves at most 1,000 ranked hits, with an explicit localized refinement notice and `search_limited` JSON flag. Counts/pages describe visible matches within that window. Selected tags are passed to Elasticsearch before retrieval; database visibility and tagging checks remain authoritative.
- Chat history loads only on modal open, in pages of 20 with a stable ID cursor. Suggestions are batched with author, tag, body, and thumbnail preloads. Pending status responses omit rendered HTML.
- Feed panel rankings are cached as IDs for one minute. Most-read posts recheck current visibility, author avatars are preloaded, and JSON results skip sidebar loading.
- Embedding triggers ignore metadata-only updates and computed vector writes. Body changes explicitly schedule embedding work. A per-post advisory lock coalesces generation; a short row lock rechecks the current source before storing the vector so edits during generation cannot receive stale vectors.
- Concurrent trigram index migrations cover post/revision titles, user names/emails, tag names, and normalized tag names.
- Chat quotas use per-user advisory locks and a persistent daily counter. The global daily row is locked briefly during reservation/creation, preserving exact limits without global history scans on every submission. Existing usage is bootstrapped once per day; failed requests remain counted.
- Docker and Kamal have separate interactive and indexing worker processes. Interactive workers use three threads; indexing uses two. Old default-queue jobs remain consumable. Embeddings now use the `embeddings` queue.

Validation: 81 Rails tests, 390 assertions, zero failures/errors; polling JavaScript regression check passes; 15 changed Ruby files pass RuboCop; Docker development compose validates; both migrations applied to the isolated test database and local Docker app. Local interactive/indexing workers restarted successfully. Production deployments still need the migrations and both worker roles.

The same local second-request measurements after changes were 53.2 ms / 14 SQL for the feed, 23.7 ms / 13 SQL for public search, and 19.3 ms / 5 SQL for admin search. Attachment loads dropped from seven to three on feed requests, and closed-modal history queries disappeared. Public-search measurement includes an unnecessary tag lookup that was subsequently removed when no tag filter is provided. Small two-request samples remain unsuitable for production latency claims; the feed timing illustrates normal measurement variation despite reduced SQL.

Broad public search now deliberately reports only its bounded window. Sidebar rankings can lag by up to one minute. Production throughput and large-dataset query plans still require representative workload measurements; code fixes do not establish a capacity guarantee.
