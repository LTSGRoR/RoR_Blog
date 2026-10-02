# Search audit — 2026-10-02

Status: the findings below describe the original audit. Fixes have since been implemented in the working tree; see the remediation section at the end.

Scope: public post search (`/posts`, `/blog`), tag links, author dashboard search, tag autocomplete, search documents, and background index updates in the current working tree. Reviewed local Searchkick 6.1.0 implementation and ran HTTP integration probes against the isolated `ror_blog_audit_test` database and temporary Elasticsearch indexes with complete Searchkick mappings. No deployed application data was inspected or changed. No application fixes were made for this audit.

## Findings

### 1. High: stale search documents can expose newly private posts

Location: `app/controllers/posts_controller.rb:185-195`, `:251-259`.

Search checks `status` and `verified` in Elasticsearch, then loads matching Post rows without applying the current database visibility scope. Visibility updates index asynchronously. During that delay, a post withdrawn from public view is still a match; the endpoint serializes its current title, full plain-text body, tags, and author. The ordinary public feed applies database visibility correctly, and the show endpoint has authorization, but those protections do not cover the search JSON response.

Reproduced: index a published verified post, set `verified: false` without processing its queued index update, and search its title anonymously. HTTP 200 includes the post body and `verified: false`. The same missing database guard applies to a change to draft status. Exposure lasts until index synchronization succeeds; if workers or Elasticsearch are unavailable, it can persist.

Recommendation: apply the public database scope when loading search hits, in addition to the index filters. Handle stale-hit counts and pagination so filtered hits do not mislead the user. Add regression coverage for unverification and withdrawal before workers run.

### 2. Medium: clicking a tag does not filter by that tag

Location: `app/views/posts/_tag_chip.html.erb:1`, `app/views/posts/index.html.erb:33,109`, `app/controllers/posts_controller.rb:188`.

Every tag link sends `q=tag.name`. That searches title, tags, and body with stemming and optional fuzzy matching. It does not require the post to carry the clicked tag. A multiword tag is also tokenized rather than treated as exact membership.

Reproduced: create one post tagged `quartzneedle` and an untagged post titled `quartzneedle title collision`. Following the query used by the tag link returns both posts.

Recommendation: give tag navigation an explicit tag identifier parameter and filter by exact membership. Keep free-text search available separately and preserve the selected tag through pagination. Consider a clear tag-search convention if typed `#tag` queries are intended.

### 3. Medium: partial tag search does not use the configured partial index

Location: `app/models/post.rb:3`, `app/controllers/posts_controller.rb:186-193`.

Post declares `word_middle` indexes for title and tags, but the controller searches ordinary analyzed fields. In the installed Searchkick implementation, a string field specification uses the default `:word` match; declaring a partial index does not automatically choose it in a query.

Reproduced: a post tagged `quartzneedle` is found by the full tag, but `artznee` returns no result. A fresh correctly mapped index reproduces this, so reindexing alone will not resolve it. Tag autocomplete separately uses `word_start` and works for prefixes after its jobs finish.

Recommendation: explicitly select partial matching for title and tags if that is the intended experience, retaining normal word matching for body. Test short prefixes, middle fragments, and multiword tags, and assess false-positive relevance.

### 4. Medium: tag suggestions accept stale asynchronous responses

Location: `app/javascript/controllers/tag_input_controller.js:22-53`.

The 200 ms debounce clears pending timers but does not abort active requests or reject responses for an older query. Clearing input, selecting a tag, or disconnecting the controller does not invalidate those responses. `disconnect` also leaves the pending debounce timer alive.

Reproduced with the actual controller and controlled fetch promises: an `old` request arriving after a `new` request replaces the newer suggestions. A response arriving after clearing the input reopens the suggestion list. Pressing Enter can consequently select a stale suggestion.

Recommendation: cancel timers and requests on query changes/disconnect, and check a request generation or current input before rendering. Check HTTP response status before parsing JSON. Cover out-of-order responses, clearing input, selection, and navigation.

### 5. Medium: search failures are reported as successful empty results

Location: `app/controllers/posts_controller.rb:196-201`, `app/controllers/tags_controller.rb:10-12`.

Both endpoints rescue search exceptions and return HTTP 200 with no results. Users cannot distinguish an outage or missing index from a genuine lack of matches. Tag autocomplete offers a no-matches/create flow even when matching tags already exist in the database.

Reproduced by simulating provider failures with matching database records: posts return `count: 0` and an empty array; tag autocomplete returns `[]`.

Recommendation: use a bounded database fallback for appropriate tag lookups, or return an explicit retryable unavailable response and show it in the UI. Log and monitor index failures without conflating them with successful searches.

## Additional observations

- Public search does not eager-load associations used by its HTML and JSON rendering, unlike the normal feed. Tags, rich-text bodies, authors, and attachments can cause additional queries for every result. Add the relevant Searchkick `includes` and measure the endpoint query count. This is a code-review finding, not a measured performance benchmark.
- Author dashboard SQL search binds the query safely, but does not escape `%` and `_` for `LIKE` (`posts_controller.rb:24`). Those characters behave as wildcards rather than literal search text. Use `sanitize_sql_like` if literal matching is intended. This does not permit SQL injection.
- Live post search aborts the preceding request only after the new debounce fires. An older response can still replace results during that interval. Invalidate active work when input changes and guard response rendering by query generation. This is a code-review observation; the deterministic JavaScript reproduction covered tag suggestions.

## Checks that passed

- Full-tag and case-insensitive public searches.
- Title, body, and multiword-tag searches.
- Case-insensitive prefix tag autocomplete after indexing completes.
- Fresh index filtering excludes drafts and unverified posts.
- Tag addition, removal, and rename produce the expected post matches after synchronization completes.
- Body-only edits enqueue an ActionText/Searchkick indexing job and become searchable after synchronization. The ActionText initializer supplies this callback even though the Post callback itself does not inspect body changes.

## Verification artifacts

`docs/audit-support/search_audit_probes.rb`: 10 probes, 42 assertions, no failures or errors. These assertions deliberately confirm the observed defects as well as working behavior; their passing does **not** mean search is healthy. Run with `RAILS_ENV=test`, a disposable PostgreSQL database, and a local test `ELASTICSEARCH_URL` using `bundle exec rails test docs/audit-support/search_audit_probes.rb`. The script creates uniquely suffixed test indexes and removes them in teardown.

`docs/audit-support/tag_suggestion_race.cjs`: two deterministic stale-response scenarios reproduced. Run from the repository root using `node docs/audit-support/tag_suggestion_race.cjs`.

The earlier moderation fixes and reaction-button removal remain separate uncommitted changes. This audit adds only documentation and reproduction artifacts.

## Remediation — 2026-10-02

- Public search reconciles ranked Elasticsearch IDs with the current public database scope before counting, paginating, and rendering. Stale private and deleted hits cannot inflate counts or expose content. Search associations are eager-loaded.
- Tag navigation uses `tag_id` and exact database membership. Tag filters work without Elasticsearch and persist through normal pagination, submitted forms, and live search; they can also combine with free text.
- Title and tag queries explicitly use `word_middle`; body searches retain normal word matching.
- Tag suggestions cancel pending work and reject outdated responses on input changes, selection, clearing, disconnect, and reconnect. Failed HTTP responses display an error. Live post search also invalidates the previous request immediately, including during debounce.
- Public search outages return HTTP 503 and a visible error, without a misleading no-matches message. Tag autocomplete falls back to an escaped database prefix lookup with a 20-result limit.
- Author dashboard search escapes SQL `LIKE` wildcards.

Regression coverage now lives in `test/integration/search_test.rb` and `test/javascript/{tag_suggestion_race,search_race}.cjs`; CI runs the JavaScript checks. The old audit-support entry points forward to these fixed-behavior checks. The original observed-defect assertions have been replaced.

Verification: the complete Rails/job/model/integration/browser run passed with 49 tests and 139 assertions. After adding HTML outage and tag-form/pagination checks, all 13 search integration tests passed with 59 assertions. Both JavaScript regression scripts passed, covering out-of-order responses, cleared input, selection, disconnect, HTTP errors, and live-search tag preservation.

Operational note: no production index changes or Docker restart were performed. Existing indexes need the declared partial-search mappings; rebuild stale indexes using the existing production operations procedure if those mappings are absent. To obtain exact database-visible totals, text search scans all matching index IDs in batches of 500 before database pagination; this adds work proportional to the number of matches and should be measured as the catalog grows.
