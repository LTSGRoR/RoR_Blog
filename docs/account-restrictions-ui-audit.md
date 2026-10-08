# Account restrictions verification — 2026-10-08

Verified using synthetic records in the isolated `ror_blog_test` database and
temporary Elasticsearch test indexes. Development posts and accounts were not modified.

## Behavior checked

- Admin ban/unban endpoints hide and restore posts and comments.
- Banned posts disappear from public feeds, profiles, search, and saved recommendation cards.
- Direct public access to a banned author's post is denied; admins retain review access.
- Suspension leaves published, verified posts visible and hides comments in English,
  Vietnamese, and Japanese. Expiry and unsuspension restore comment content.
- Existing replies from other users survive hidden parents. New replies and reactions
  to hidden comments are rejected, including submissions from stale forms.
- Previously authenticated banned/suspended sessions cannot access author actions.
- Unbanning preserves verification status; unverified posts remain private.
- Real Elasticsearch results react to ban/unban without reindexing.
- Reactions by restricted users are excluded from post/comment counts and ranking
  totals. Ban/unban and suspension/expiry restore the original reactions without deletion.

## UI review

Reviewed against [Web Interface Guidelines](https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md).

- Desktop (1280px) and mobile (390px) checks passed for translated placeholders,
  preserved reply threads, restored comments, and no horizontal overflow.
- Ban and suspension dialogs fit both viewports. Focus enters and stays inside the
  dialog, Escape closes it, and focus returns to the trigger.
- Fixed narrow reply headers: author names and timestamps now stack on mobile.
- Fixed stale reply forms: a translated explanation replaces the form when its
  parent comment becomes hidden.
- Visually inspected screenshots of hidden threads and both admin dialogs.

The browser harness uses full HTML rendered by real test requests and the app's
JavaScript/assets. It blocks mutations to development data. Account actions are
verified by integration requests rather than browser form submissions.

Existing open pages reflect account visibility on their next request or refresh;
this change does not add live replacement of content already displayed in a browser.

## Reproducing checks

With the Rails test database and Elasticsearch available:

```sh
bin/rails test test/models/account_content_visibility_test.rb test/models/public_search_performance_test.rb test/integration/account_restrictions_test.rb test/integration/authorization_test.rb test/integration/search_test.rb test/integration/chat_history_performance_test.rb test/jobs/chat_generation_test.rb
bundle exec ruby test/models/account_content_rendering_test.rb
```

To generate browser fixtures, run the restriction integration test with
`ACCOUNT_UI_SNAPSHOTS=true`. With the development app running at `localhost:3000`
and Playwright/Chromium installed:

```sh
node test/javascript/account_restriction_ui.cjs
```

The browser script also accepts a Playwright module path and Chromium executable
path as its first and second arguments.
