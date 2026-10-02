# Admin post search audit — 2026-10-02

Status: the findings below describe the original audit. The fixes and tag-search enhancement have since been implemented locally; see remediation below.

Scope: Manage Posts search, revision search, scope/filter interactions, pagination, and access control. Verified with six HTTP integration probes against the isolated audit database (37 assertions). No application changes were made.

## Confirmed bugs

1. **Revision search checks the parent title instead of the displayed revision title.** `app/controllers/admin/posts_controller.rb:65-70` searches `posts.title`, while the table displays `revision.title`. A pending revision titled “Unique revision title” under a post titled “Parent title” is absent when searching “Unique revision” but appears when searching “Parent title”. Search `post_revisions.title`, optionally alongside the parent title.

2. **Percent and underscore act as SQL wildcards.** Both queries wrap raw input in `%...%` without escaping SQL `LIKE` wildcard characters (`:25`, `:69`). Searching `%` or `_` matches unrelated posts and revisions. Use `sanitize_sql_like` before building the pattern. The bound query is safe from SQL injection; the defect is incorrect literal matching.

## Search capability gap

Tags are not searched in either scope, even though post tags are displayed in the table. A tag attached to both a post and revision produces no matches when its name occurs only in tags. The current placeholder advertises title/author search, so this is a missing capability rather than a broken advertised one. If admin search should align with public/dashboard tag search, add association membership matching using subqueries or `EXISTS` to avoid duplicate rows and incorrect pagination.

## Checks that passed

- Case-insensitive partial post-title matching.
- Author name and email matching for posts and revisions.
- Post status filters and revision state filters remain applied to search results.
- Pagination preserves query, scope, and filter parameters, with the expected second-page row count.
- Non-admin authors receive HTTP 403; anonymous visitors must sign in.
- Search uses database queries, so it does not depend on Elasticsearch availability.

Queue statistics remain global rather than counting only the current search results. Draft posts are excluded from the post moderation table by its published-post scope. These are existing dashboard behaviors, not classified as defects here.

The probe assertions confirm observed behavior, including the defects; passing them does not imply the bugs are fixed. Production data and performance at production scale were not inspected.

## Remediation

- Revision searches match both their own title and the parent post title.
- Both searches escape SQL wildcard characters and match author names and emails case-insensitively.
- Post search matches the post's tags; revision search matches the revision's own tags. Correlated `EXISTS` queries avoid duplicate rows when multiple tags match, keeping filters and pagination accurate.
- English, Vietnamese, and Japanese placeholders now describe title, author, email, and tag searching.
- Permanent regression coverage is in `test/integration/admin_post_search_test.rb`, including literal wildcard matches, tag independence, duplicate prevention, authorization, filters, and pagination.
- Existing Docker data exposed an additional mismatch: `machine learning` did not match the stored tag `machine-learning`. Tag queries now normalize spaces and hyphens while preserving literal wildcard escaping. Read-only authenticated requests against the existing Docker database returned both matching posts for `machine`, `machine learning`, and `machine-learning`, all with HTTP 200. Regression verification passed with nine tests and 64 assertions; lint is clean.

No Elasticsearch dependency, schema migration, commit, or deployment was introduced by this change.
