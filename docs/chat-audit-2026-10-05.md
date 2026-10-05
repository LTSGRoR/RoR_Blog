# Chat session audit — 2026-10-05

Scope: account conversations, sidebar/composer behavior, history deletion, generation/RAG, localization, and access control on branch `feature/account-chat-sessions`, commit `c98cf64`.

## Findings

1. **P2 — Stale session responses overwrite current state.** `app/javascript/controllers/ai_modal_controller.js:98` replaces the conversation list without reconciling creations or deletions made while the request was running. A deferred-response JavaScript reproduction confirmed that creating session 42 while an older list response is pending removes session 42 from the sidebar when the response arrives. A stale response can likewise restore a deleted row. Initial selection also overwrites a draft typed before the first session response finishes (`selectSession`, line 210). Use a mutation/version guard, preserve drafts, and reconcile by session ID.

2. **P2 — Opening the sidebar discards loaded pages.** `app/javascript/controllers/ai_modal_controller.js:133` calls `loadSessions()` on every opening. Without a pagination event, line 98 replaces all loaded conversations with the first page. Older pages disappear, and an active older conversation may no longer appear because restoration only runs when there is no active session. Preserve loaded pages and the active conversation when refreshing; deduplicate IDs when appending pages.

3. **P2 — Enter submits during IME composition.** `app/javascript/controllers/ai_modal_controller.js:26` does not check `isComposing`. Confirmed with an Enter event carrying `isComposing: true`: `submit()` is called. Japanese users can accidentally send unfinished text while accepting a composition candidate. Ignore composing key events, including the browser compatibility case where keyCode is 229.

4. **P2 — Empty conversation creation has no application limit.** `app/controllers/chat_sessions_controller.rb:18` inserts a session on every authenticated POST. Message quotas do not apply to this endpoint, and deletion retains the session row. An authenticated client can accumulate unlimited empty/deleted sessions without generating a single message. Add a bounded creation rate and a deliberate retention policy for unused sessions. Severity reflects resource consumption; no cross-account access was found.

5. **P3 — Error responses are not fully localized.** `app/controllers/chat_controller.rb:30` and `app/models/chat_history.rb:40` return English validation/quota text; `app/jobs/generate_post_suggestion_job.rb:6` persists an English generation failure. These can appear in Vietnamese/Japanese chat UI despite translated controls. Use translation keys, and retain the request locale for background responses.

## Validation

- Chat sessions integration, chat generation jobs, and chat history performance: **15 tests, 102 assertions, zero failures/errors** against the isolated local test database.
- `node test/javascript/chat_session_submission.cjs`: passed.
- `node test/javascript/chat_polling.cjs`: passed.
- Additional temporary JavaScript reproductions confirmed stale-list overwrite and IME submission. These reproductions did not change application code.
- Reviewed ownership-scoped CRUD/history/status access, row locking around deletion and message acceptance, quota preservation after deletion, conversation-local retrieval, and published/verified suggestion filtering. Existing tests cover foreign-session rejection and deletion during generation.
- Keyboard/focus review followed the [Web Interface Guidelines](https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md). The custom confirmation dialog stops keyboard propagation, preventing the underlying chat focus trap from handling its events.

This is a source and targeted regression audit, not a production load test.

## Fix verification

All five findings were addressed after the audit: list merging and deletion tombstones protect asynchronous updates; reopening preserves loaded pages; composition events do not submit; conversation creation uses a PostgreSQL advisory lock and a rolling-hour limit with bounded cleanup of old deleted empty sessions; errors and generation failures are translated, with request locale passed to jobs.

Backend and browser regression suites passed: **21 tests, 179 assertions, zero failures/errors**. JavaScript checks cover polling, first-message creation, duplicate submissions, failed-creation drafts, late sidebar responses, pagination deduplication, initial drafts, and IME Enter. RuboCop passed for all six changed Ruby source/test files. The fixes are uncommitted.
