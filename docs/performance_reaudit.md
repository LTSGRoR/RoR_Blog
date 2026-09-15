# Performance reaudit (Sep 2026)

Measured with /tmp/perf_probe.rb against the local seed DB (35 posts /
12 users / 1 comment) plus a synthetic "hot post" carrying 12 root comments
x 3 replies and 49 reactions, rendered through the real Rack stack.
Baselines ("before") stashed to run the identical probe against the untouched
tree; results after the changes ("after"):

Path                               before ms  queries | after ms  queries
GET / (landing)                        61.9ms     18 |     59.9ms     14
GET /blog                              73.5ms     27 |     69.2ms     19
GET /blog?page=2                       81.0ms     27 |     81.8ms     19
GET /posts/:hot (comment tree)        122.4ms    117 |     91.4ms     41
GET /posts/:plain                      62.3ms     24 |     64.7ms     19
GET /users/:id                         55.4ms     12 |     53.8ms      9
GET /team                              55.6ms     13 |     54.4ms      7
GET /posts/mine (author)               54.6ms     14 |     55.5ms      8
GET /posts/mine?filter=all            ~53ms      14 |    ~55ms       8
GET /admin/posts (admin)               62.2ms     15 |     70.8ms     10
---

## What was fixed (for the commit message / PR body)

1. Reaction bar (`app/views/reactions/_bar.html.erb`) used to issue one
   GROUP BY plus one viewer lookup per reactable; on a hot comment thread
   that was 2 queries x every visible comment/reply. It now aggregates the
   already-loaded `reactions` association in memory when the caller
   eager-loaded it, and only falls back to SQL otherwise.
2. `PostsController#show` now preloads the comment tree two replies deep
   (`user` + avatar attachment/blob, `post`, `parent`, `reactions`) so the
   per-node queries for avatars, posts, parents and reaction bars disappear;
   `_replies_frame` reuses the loaded `replies` collection instead of
   re-querying it with `.order(...)` + an extra `.any?` EXISTS per node.
3. `includes(:comments)` on the public feed loaded every comment row of
   every listed post just to print a count. A `posts.comments_count`
   counter cache (`Comment belongs_to :post, counter_cache: true` plus the
   `20260915120000` migration with a backfill) makes `post.comments.size`
   free in the feed cards, the mine table, the author profile and the
   "most read" sidebar.
4. "Most read" sidebar no longer LEFT JOINs comments AND reactions together
   (comments x reactions cartesian product with COUNT(DISTINCT ...));
   correlated sub-selects read the same metrics off the FK indexes.
5. `Post#active_revision` previously ran one query per row on the author
   dashboard (`mine.html.erb` calls it for every post); when
   `post_revisions` is already loaded (the dashboard preloads it) the
   current draft/pending-revision is now picked in memory.
6. Dashboard/user counters that each ran 3-8 separate COUNTs now use a
   single FILTER-aggregate query (`PostsController#posts_status_counts`,
   `UsersController#summarize_status_counts`,
   `Admin::PostsController#load_review_queue_stats`); the admin reviewer
   chips no longer `User.find_by` per reviewer, and the per-locale broadcast
   loop in `UsersController#broadcast_user_and_summary` no longer recomputes
   the full user ordering and the status counters for every locale.
7. Profile page no longer `includes(:posts)` (it loaded every post of the
   author plus attachments to render three) and the duplicated
   verified-posts COUNT is gone; pages/landing/team preload the rich-text
   bodies, tags and avatar attachments/blobs they actually render.
8. Comment avatars are served through the representation endpoint
   (`image_tag variant`) like every other avatar in the app, instead of
   `.processed` synchronously generating the variant inside the page render.
9. AI chat job embedded the same user message twice (once for the post RAG
   search, once for the chat-history RAG search); the user message is now
   embedded once and the vector is reused for both searches, and the stray
   `when nil` branch is gone.
10. Added targeted composite indexes (feed ordering, owner+visibility,
    comment tree, revision lookup, chat-history-per-user, reactions per
    reactable+emoji) and dropped the two narrower indexes they supersede;
    `db/schema.rb` regenerated from the two new migrations.

## Intentionally NOT changed (follow-ups, not this audit)

- Turbo `_later` broadcasts (7 per AI-status update) move rendering into
  jobs already; combining the admin_posts streams would change the DOM
  contract of the live-update cells.
- Searchkick/Elasticsearch and the pgvector ivfflat probes are external
  services; no query routing was changed.

