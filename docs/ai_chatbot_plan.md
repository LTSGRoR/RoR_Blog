# Plan: AI Chatbot — Robust Async Job + Persistence

TL;DR — Implement a resilient async flow that generates AI suggestions, persists them, and delivers them to the editor via Turbo Streams. This is designed for reliability (rate limits, retries) and auditability (stored prompts/results).

## High-level Steps (what I'll deliver in the plan)
1. DB schema: migration for `chat_histories` table to persist user messages and chatbot responses, provider metadata, and UI metadata.
2. Model: `ChatHistory` ActiveRecord model including associations to `User` and `Post` and helpers for querying/history display.
3. Service: `app/services/ai_generation/service.rb` that builds provider prompts, calls `RubyLLM.chat` (via existing `AiModeration::Configuration`), and returns raw/structured result.
4. Job: `GeneratePostSuggestionJob` (ActiveJob/Sidekiq) that performs generation, persists result, handles transient errors & retries, and broadcasts Turbo Stream to the user when done.
6. Controller & Routes: `app/controllers/posts/ai_suggestions_controller.rb` with `create` action to validate request, create a pending `AiGeneratedSuggestion` record, enqueue the job, and return a 202 with the suggestion id.
7. Front-end: Stimulus controller `ai_assistant_controller.js` to call the `create` endpoint, show progress, subscribe to Turbo Stream updates, and insert suggestions into the ActionText editor when received.
8. Admin & UX: Add an admin view to inspect stored suggestions and moderation outcome; enable manual override or re-run generation.
9. Tests & Docs: specs for model/service/job/controller and a README snippet explaining env vars, costs, and rollout steps.

## Concrete Implementation Steps (detailed, ordered)
1. Migration (blocking): create migration `CreateChatHistories` with fields:
   - `user_id:bigint`, `post_id:bigint` (nullable)
   - `user_message:text`, `bot_response:text` (store HTML/plain), `provider:string`, `provider_meta:jsonb`,
   - `meta:jsonb` (ui/usage metadata), timestamps
   - Indexes on `user_id` and `post_id`
2. Model (parallel with migration): `app/models/chat_history.rb`
   - Associations: `belongs_to :user`, `belongs_to :post, optional: true`
   - Validations for presence of `user_message` and `bot_response`
   - Methods: helpers for `for_user`, `recent_for_post`, and `as_message_pair` formatting
3. Service (parallel): `app/services/ai_generation/service.rb`
   - API: `generate(prompt:, user:, context: {})` returns a struct `{ provider:, result:, meta: {} }`
   - Uses `AiModeration::Configuration` and `RubyLLM.chat` to call the configured provider. Include timeout and retry wrappers.
4. Job (blocking for UX): `app/jobs/generate_post_suggestion_job.rb`
   - `perform(chat_history_id)` or `perform(user_id, post_id, user_message)` builds prompt from the user message, calls `AiGeneration::Service.generate`, persists a `ChatHistory` record (or updates a pending one) with `bot_response` and `provider_meta`, then broadcasts a Turbo Stream (private channel / stream keyed by user id) with partial `_chat_history_item.html.erb`.
   - Error handling: capture transient errors (network/timeouts) and re-raise to let Sidekiq retry; mark permanent failures after N attempts and record `error`.
5. Controller & Routes (after job): `app/controllers/posts/chat_controller.rb`
   - `create`: authorize user (Pundit), accept `message` or `topic` params, create a pending `ChatHistory` record (user_message set, bot_response blank), enqueue `GeneratePostSuggestionJob.perform_later(chat_history.id)` (or pass user/post/message), respond `202` with JSON `{ id: chat_history.id }`.
   - Route: `resources :posts do post 'chat', to: 'posts/chat#create' end` (or `resources :chat_histories, only: [:create]` nested under posts)
6. Front-end Stimulus (parallel): `app/javascript/controllers/ai_assistant_controller.js`
   - Actions: on click, POST to `/posts/:post_id/ai_suggestions` with `prompt_type` or `topic`, display loading state, then listen for Turbo Stream broadcast (e.g., `turbo-stream-from="ai_generated_suggestions_user_#{current_user.id}"`) and insert suggestion into the Trix editor when received.
   - UI: show previous suggestions list, allow accept/insert, re-run, or delete suggestion.
7. Turbo Stream partials & templates: `app/views/chat_histories/_chat_history_item.html.erb` to render a message pair and a `turbo_stream` partial to append/replace in the editor sidebar or chat panel.
8. Admin tools: `app/controllers/admin/chat_histories_controller.rb` and admin views to list and inspect chat history; allow re-run or delete.
9. Tests & CI: add RSpec tests for service and job (mock RubyLLM), controller request specs, and system test to exercise the end-to-end Turbo Stream flow.

## Verification & Rollout
- Local dev: run migrations, then start Sidekiq. Use:
```bash
bin/rails db:migrate
bundle exec sidekiq
```
- Manual test: request generation from post edit page, confirm Turbo Stream arrives and suggestion inserted.
- (No moderation step) The feature does not auto-run moderation; generated suggestions are delivered to the author for review before publishing.
- Load test: simulate many concurrent requests to ensure Sidekiq queues and provider timeouts handled.
- Rollout: feature-flag behind `ai_suggestions_enabled` env var and enable for beta users first.

## Security, Cost, and Operational Considerations
- Enforce authorization: only editors/authors can create suggestions; validate post ownership.
- Rate limiting & quotas: per-user daily caps and admin-configurable global caps to control cost.
- Prompt & result storage: store prompts/results for audit but redact sensitive data in logs; use DB encryption if required.
- Prompt & result storage: store prompts/results for audit but redact sensitive data in logs; use DB encryption if required.
- Monitoring & alerts: add Sidekiq dashboard, instrument job failure rates, and track API error budgets.

## Files to Add/Modify
- Migration: `db/migrate/XXXX_create_ai_generated_suggestions.rb`
- Model: `app/models/ai_generated_suggestion.rb`
- Service: `app/services/ai_generation/service.rb`
- Job: `app/jobs/generate_post_suggestion_job.rb`
- Controller: `app/controllers/posts/ai_suggestions_controller.rb`
- Views/Partials: `app/views/ai_generated_suggestions/_ai_generated_suggestion.html.erb` and Turbo Stream partials
- Stimulus: `app/javascript/controllers/ai_assistant_controller.js`
- Admin: `app/controllers/admin/ai_generated_suggestions_controller.rb`, `app/views/admin/ai_generated_suggestions/*`
- Tests: specs under `spec/services`, `spec/jobs`, `spec/requests`, `spec/system`

## Open Questions
1. Persistence scope: should suggestions always be stored, or only when user opts to save? (Recommend store by default for auditability.)
2. UX: do you want a sidebar with history, or a lightweight modal per request? (Plan uses a sidebar for history.)
3. Provider policy: do we prefer local Ollama models for cost/privacy? (Recommend starting with configured `RubyLLM` provider but allow provider override per environment.)
