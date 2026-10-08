# Blog assistant scope and prompt boundaries

The assistant explains, summarizes, compares, and recommends blog posts. It may
explain code already present in a supplied post, but does not write new code,
compose articles, solve standalone math, or answer unrelated general questions.

## Admin settings

The AI settings page remains the source of the assistant's editable system prompt.
The latest saved prompt is loaded for each request and sent through RubyLLM's
actual system role. It controls tone and blog-specific guidance within the fixed
reading scope. It cannot turn the assistant into a general-purpose chatbot or
disable the application's scope checks. Existing chats are not regenerated.

## Request flow

1. Obvious role overrides and calculator expressions receive a localized scope
   refusal without requesting generation or embeddings.
2. Other requests pass a separate structured scope check. The classifier sees
   the question and limited previous user messages, not retrieved post content
   or editable admin instructions.
3. Allowed questions retrieve relevant posts. Questions, post text, and conversation
   history are JSON data, separate from system instructions. Prior assistant
   answers are not factual evidence.
4. A separate structured response check inspects the answer against the question
   and supplied post evidence before anything is stored or broadcast.
5. Refused requests/answers have no recommendation cards or embeddings and are
   excluded from future conversation context.

Invalid classifier decisions refuse the request. Provider failures produce the
existing translated unavailable message; an unchecked answer is never published.
Scope refusals and settings guidance support English, Vietnamese, and Japanese.

Allowed substantive questions incur two extra provider calls for the request and
response checks. Exact greetings skip classification and retrieval but still
have their generated response checked. Each check uses the configured model/provider.

These are layered safeguards, not a guarantee against every possible injection.
The additional judges are themselves language models; adversarial and multilingual
evaluation should continue after changing the model or these rules. No tools or
arbitrary code execution are enabled for this assistant.

## Verification

Database regression tests cover provider role separation, changed admin prompts,
blocked requests, localized refusals, rejected responses, malformed decisions,
gate outages, and rejected conversation history. Existing chat, authorization,
and history regression suites are included.

On 2026-10-08, a live evaluation against the configured provider passed 12 checks:
direct overrides, arithmetic, unrelated code, classifier spoofing, prompt extraction,
Vietnamese overrides, Japanese unrelated requests, legitimate summaries, existing
code explanations, prompt injection as a legitimate blog topic, indirect post
injection, and rejection of a deliberately unrelated generated answer.

Run offline regression checks:

```sh
bundle exec ruby test/models/assistant_policy_test.rb
bin/rails test test/jobs/assistant_scope_test.rb test/jobs/chat_generation_test.rb test/integration/assistant_prompt_settings_test.rb
```

Run the optional live evaluation (makes provider API requests):

```sh
bin/rails runner test/scripts/assistant_security_eval.rb
```

References: [RubyLLM system instructions](https://rubyllm.com/chat/) and
[OWASP prompt injection prevention](https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html).
