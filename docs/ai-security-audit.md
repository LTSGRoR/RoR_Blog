# AI security audit — 2026-10-08

Scope: chat and chat-session endpoints, assistant policy gates, retrieval, generation and embedding calls, automatic post/revision moderation, admin settings, background-job persistence, and response rendering. This is a source audit with mocked-provider regression tests, not a penetration test against production or live model providers.

## Findings and changes

| Severity | Finding | Change |
| --- | --- | --- |
| High | Moderation sent administrator criteria and author-controlled content in the same user message, weakening the instruction boundary for decisions that can publish posts/revisions. | Send review criteria as system instructions and article JSON as user data. Explicitly instruct the model to treat embedded commands as untrusted and route approval overrides to human review. |
| High | The moderation parser coerced scores and did not validate the complete response shape; an approval with confidence above 1 could pass the threshold. | Require the four expected fields, a known verdict, numeric finite scores in [0,1], a nonblank string reason, and a valid threshold. Invalid responses fail closed. |
| Medium | A queued chat could run after account restrictions, session deletion, or loss of access to its anchor post. Returned text was not rechecked when retrieved posts became inaccessible during generation. | Recheck account/session and anchor authorization before provider work and post access before saving an answer. Use the same post policy as HTTP requests. Skip cleared requests. |
| Medium | Generation and moderation changed RubyLLM's process-global credentials and timeout, allowing concurrent Sidekiq jobs to interfere during configuration changes. | Use isolated RubyLLM contexts for chat, policy checks, moderation, and embeddings. |
| Medium | Accepted chat questions could appear in Rails request parameter logs. | Filter message and user_message parameters. This does not sanitize historical logs or arbitrary exception messages. |
| Medium | The generation-failure path checked then saved without locking, allowing a concurrent clear operation to be overwritten. | Check and persist the terminal failure while holding the chat row lock, and leave cleared/completed messages untouched. |

## Existing safeguards checked

Chat history/session lookups are scoped to the authenticated user. HTTP post access uses Pundit. Retrieval scopes public posts and limits conversation history to the same user/session. Suggested cards are restricted to supplied candidate IDs and currently public posts. Chat limits are enforced using database locks and a daily quota. AI settings require an administrator policy, API keys are encrypted at rest, and blank key fields preserve the saved key. Responses are escaped before HTML formatting; model text is not rendered as trusted HTML. The assistant uses separate request/response scope gates and keeps the administrator's style prompt within the fixed reading scope.

## Limits and remaining risks

System roles and scope gates reduce prompt injection risk; they do not make model decisions deterministic or guarantee correct moderation. Request and response gates share the configured model/provider. No live adversarial-model test was performed. Test attacks against each configured provider in staging before relying on automatic approval for high-risk content.

External providers receive eligible post excerpts, chat questions/history, and complete submissions for moderation. Provider retention and data-use settings were not audited. Clearing local history cannot retract data already sent to a provider. Authorization rechecks reject changes observed before generation and persistence; they cannot cancel an in-flight provider request or guarantee atomicity with a separate concurrent moderation transaction.

Quota controls limit accepted chats, but one accepted request may make several paid calls. Provider-side spending limits and maximum output budgets are separate operational controls. Existing provider exception strings are still logged/stored in failure metadata; the audit does not establish that every provider error is free of sensitive data.

## Validation

`bundle exec ruby test/models/ai_security_test.rb`: 6 tests, 38 assertions passed. `bundle exec ruby test/models/assistant_policy_test.rb`: 4 tests, 26 assertions passed. Rails eager loading and whitespace checks passed. Added database-backed tests for restrictions applied after enqueue and post visibility revoked during generation in `test/jobs/chat_generation_test.rb`; these were not executed because the local Docker daemon is unavailable. No production data, services, or provider settings were changed.
