## Overview
The AI auto-post verification system uses Large Language Models (LLMs) to automatically review and moderate newly created posts and post revisions. It determines whether content can be auto-approved or requires manual admin review.

### Pipeline:
```
Content Created/Updated
     │
     ▼
Moderation Configuration
     │
     ▼
Payload Builder
     │
     ▼
LLM Client (RubyLLM)
     │
     ▼
Decision Parser
     │
     ▼
Decision Handler
     │
     ├── auto_approve → Post Verified (auto-approved)
     ├── needs_admin_review → Flagged for Admin
     └── failed → Retry / Fallback
```

---

## Architecture

### 1. Content Triggers
**Responsibilities**
- Detect when new content is created or updated
- Enqueue AI review jobs for eligible content

**Triggers**
- **Post created/updated** (`PostsController#create`, `PostsController#update`)
- **Post revision submitted** (`PostRevisionsController#create`, `PostRevisionsController#update`, `PostRevisionsController#submit`)
- **Admin rerun** (`Admin::PostsController#rerun_ai_review`)

**Eligibility checks**
- Post must be `published?`
- Post must NOT be `verified?`
- AI review must be enabled (`auto_review_enabled`)
- Revision must be `pending_review?`

**Code locations**
- `app/controllers/posts_controller.rb` — `enqueue_ai_review_for(post)`
- `app/controllers/post_revisions_controller.rb` — `enqueue_ai_review_for(revision)`
- `app/controllers/admin/posts_controller.rb` — `rerun_ai_review`

---

### 2. Moderation Configuration
**Purpose**
Centralized configuration for AI moderation behavior.

**Responsibilities**
- Read settings from `ModerationSetting` model (DB)
- Fallback to environment variables
- Resolve provider API keys

**Configuration keys**

| Key | Source | Default |
|-----|--------|---------|
| `provider` | `ModerationSetting#provider` or `AI_MODERATION_PROVIDER` env | `"mistral"` |
| `model_name` | `ModerationSetting#ai_model` or `AI_MODERATION_MODEL` env | `"mistral-small-latest"` |
| `auto_approve_threshold` | `ModerationSetting#auto_approve_threshold` or `AI_MODERATION_AUTO_APPROVE_THRESHOLD` env | `0.9` |
| `request_timeout_seconds` | `ModerationSetting#request_timeout_seconds` or `AI_MODERATION_TIMEOUT_SECONDS` env | `30` |
| `max_retries` | `ModerationSetting#max_retries` or `AI_MODERATION_MAX_RETRIES` env | `3` |
| `auto_review_enabled` | `ModerationSetting#auto_review_enabled` or `AI_MODERATION_ENABLED` env | `true` |
| `new_post_instruction` | `ModerationSetting#new_post_instruction` | Default moderation prompt |
| `revision_instruction` | `ModerationSetting#revision_instruction` | Default revision prompt |
| `api_key` | `ModerationSetting#api_key` (encrypted, admin UI) **or** the provider's env var | env var is the deployment default; the admin-UI value wins when both are set (`Configuration.provider_api_key`) |

**Supported providers**

| Provider | Env Key |
|----------|---------|
| `openai` | `OPENAI_API_KEY` |
| `gemini` | `GEMINI_API_KEY` |
| `claude` | `ANTHROPIC_API_KEY` |
| `mistral` | `MISTRAL_API_KEY` |

**Code location**: `app/services/ai_moderation/configuration.rb`

---

### 3. Payload Builder
**Purpose**
Construct the content payload sent to the LLM for review.

**Responsibilities**
- Extract relevant fields from the model
- Format as a structured JSON hash

**Payload for Post**
```json
{
  "type": "post",
  "locale": "en",
  "post_id": 1,
  "title": "Post Title",
  "body": "Post body plain text...",
  "tags": ["ruby", "rails"]
}
```

**Payload for Revision**
```json
{
  "type": "post_revision",
  "locale": "en",
  "revision_id": 1,
  "post_id": 1,
  "title": "Revised Title",
  "body": "Revised body plain text...",
  "tags": ["ruby", "rails"]
}
```

**Code location**: `app/services/ai_moderation/review_payload_builder.rb`

---

### 4. LLM Client
**Purpose**
Send content to the configured LLM provider and receive a moderation decision.

**Responsibilities**
- Validate provider configuration
- Configure RubyLLM with API key and timeout
- Build prompt with instruction + content payload
- Request structured JSON response from LLM
- Parse response via DecisionParser

**Expected LLM Response Schema**
```json
{
  "verdict": "auto_approve or needs_admin_review",
  "confidence": 0.95,
  "risk_score": 0.05,
  "reason": "Content appears safe and policy-compliant"
}
```

**Prompt structure**
```
{instruction}

Return strict JSON only with keys: verdict, confidence, risk_score, reason.
JSON schema expectations:
{"verdict":"auto_approve or needs_admin_review","confidence":"float from 0 to 1","risk_score":"float from 0 to 1 where higher means riskier","reason":"short string reason"}

Content payload:
{content_payload.to_json}
```

**Error handling**
- Catches all `StandardError` exceptions
- Returns a `Decision` with `status: :failed` and error details
- Transient errors (timeouts, connection resets) trigger retries in the job layer

**Code location**: `app/services/ai_moderation/client.rb`

---

### 5. Decision Parser
**Purpose**
Parse the raw LLM response into a structured `Decision` object.

**Responsibilities**
- Strip markdown code fences (```json ... ```)
- Parse JSON response
- Compare confidence against threshold
- Return structured Decision

**Decision Struct**
```ruby
Decision = Struct.new(
  :status,      # :auto_approve | :needs_admin_review | :failed
  :confidence,  # Float or nil
  :risk_score,  # Float or nil
  :reason,      # String
  :payload,     # Hash (raw parsed JSON)
  keyword_init: true
)
```

**Decision logic**
- `verdict == "auto_approve"` AND `confidence >= threshold` → `:auto_approve`
- Otherwise → `:needs_admin_review`
- JSON parse failure → `:failed`

**Code location**: `app/services/ai_moderation/decision_parser.rb`

---

### 6. Decision Handler
**Purpose**
Process the AI decision and update the content's state accordingly.

**Responsibilities**
- Record AI decision metadata on the model
- Execute the appropriate action based on decision status

**Decision flow for Posts**

| Decision | Action |
|----------|--------|
| `:auto_approve` | Find admin user via `ActorResolver` → `post.verify!(admin)` → `post.mark_ai_auto_approved!` |
| `:needs_admin_review` | `post.mark_ai_needs_admin_review!(reason:)` |
| `:failed` | `post.mark_ai_failed!(reason:)` → retry if transient error |

**Decision flow for Revisions**

| Decision | Action |
|----------|--------|
| `:auto_approve` | Find admin user → `revision.approve!(admin:, note:)` → `revision.mark_ai_auto_approved!` |
| `:needs_admin_review` | `revision.mark_ai_needs_admin_review!(reason:)` |
| `:failed` | `revision.mark_ai_failed!(reason:)` → retry → fallback to `needs_admin_review` |

**AI Review Statuses** (shared by both Post and PostRevision)
- `pending` (0) — Queued for review
- `in_progress` (1) — Review in progress
- `auto_approved` (2) — AI approved
- `needs_admin_review` (3) — Requires manual admin review
- `failed` (4) — AI review failed

**Code locations**
- `app/jobs/moderate_post_job.rb` — Post decision handler
- `app/jobs/moderate_post_revision_job.rb` — Revision decision handler
- `app/models/post.rb` — `queue_ai_review!`, `mark_ai_*!`, `record_ai_decision!`, `verify!`
- `app/models/post_revision.rb` — `queue_ai_review!`, `mark_ai_*!`, `record_ai_decision!`, `approve!`

---

### 7. Actor Resolver
**Purpose**
Resolve the admin user account used for AI auto-approval actions.

**Responsibilities**
- Look up admin by `AI_MODERATION_ADMIN_EMAIL` env var
- Fallback to first admin user by ID

**Code location**: `app/services/ai_moderation/actor_resolver.rb`

---

### 8. Background Jobs
**Purpose**
Asynchronously execute AI moderation to avoid blocking HTTP requests.

**Responsibilities**
- Fetch content with eager-loaded associations
- Validate eligibility (published, not verified, feature enabled)
- Call AI moderation pipeline
- Handle decisions and errors
- Retry on transient failures

**Retry behavior**

| Job | Transient errors | Max retries | Fallback |
|-----|-----------------|-------------|----------|
| `ModeratePostJob` | Timeout, connection reset, broken pipe, etc. | `max_retries` config | `mark_ai_failed!` |
| `ModeratePostRevisionJob` | All `StandardError` | `max_retries` config | `mark_ai_needs_admin_review!` |

**Code locations**
- `app/jobs/moderate_post_job.rb`
- `app/jobs/moderate_post_revision_job.rb`

---

## Data Layer

### Database Schema

**`moderation_settings` table**
| Column | Type | Default | Description |
|--------|------|---------|-------------|
| `provider` | string | `"ollama"` | AI provider name |
| `ai_model` | string | `"gemma4:latest"` | Model name |
| `auto_approve_threshold` | float | `0.9` | Confidence threshold |
| `request_timeout_seconds` | integer | `30` | LLM request timeout |
| `max_retries` | integer | `3` | Max retry attempts |
| `auto_review_enabled` | boolean | `true` | Feature toggle |
| `new_post_instruction` | text | — | Moderation prompt for posts |
| `revision_instruction` | text | — | Moderation prompt for revisions |
| `api_key` | text (encrypted) | — | Provider API key |
| `assistant_prompt` | text | — | AI chat assistant prompt |

**AI review fields on `posts` and `post_revisions`**
| Column | Type | Description |
|--------|------|-------------|
| `ai_review_status` | integer (enum) | Current review status |
| `ai_confidence` | float | LLM confidence score |
| `ai_risk_score` | float | LLM risk assessment |
| `ai_provider` | string | Provider used for review |
| `ai_model_name` | string | Model used for review |
| `ai_attempts_count` | integer | Number of review attempts |
| `ai_last_error` | text | Last error message |
| `ai_reviewed_at` | datetime | When review completed |
| `ai_decision_payload` | jsonb | Raw LLM response payload |

### Indexes
- `index_posts_on_ai_review_status`
- `index_post_revisions_on_ai_review_status`

---

## Project Structure

```
app/
│
├── controllers/
│   ├── posts_controller.rb              # Enqueues AI review on create/update
│   ├── post_revisions_controller.rb     # Enqueues AI review on submit
│   └── admin/
│       └── posts_controller.rb          # Rerun AI review for failed posts
│
├── models/
│   ├── post.rb                          # AI review state machine, verify!
│   ├── post_revision.rb                 # AI review state machine, approve!
│   └── moderation_setting.rb            # Configuration model
│
├── jobs/
│   ├── moderate_post_job.rb             # Background job for post review
│   └── moderate_post_revision_job.rb    # Background job for revision review
│
├── services/
│   └── ai_moderation/
│       ├── configuration.rb             # Config resolution
│       ├── client.rb                    # LLM client
│       ├── review_payload_builder.rb    # Content payload construction
│       ├── decision_parser.rb           # LLM response parsing
│       ├── actor_resolver.rb            # Admin user resolution
│       └── model_puller.rb              # Ollama model pull utility
│
└── views/
    └── admin/
        └── posts/                       # Admin UI for AI review status
```

---

## Folder Responsibilities

### `app/services/ai_moderation/`
- **configuration.rb** — Read settings from DB/env, resolve API keys
- **client.rb** — Send content to LLM, receive moderation decision
- **review_payload_builder.rb** — Build structured content payloads
- **decision_parser.rb** — Parse LLM JSON response into Decision struct
- **actor_resolver.rb** — Find admin user for auto-approval actions
- **model_puller.rb** — Pull Ollama models (utility)

### `app/jobs/`
- **moderate_post_job.rb** — Orchestrate post moderation pipeline
- **moderate_post_revision_job.rb** — Orchestrate revision moderation pipeline

### `app/models/`
- **post.rb** — AI review state transitions, verification logic
- **post_revision.rb** — AI review state transitions, approval logic
- **moderation_setting.rb** — Persisted configuration, default prompts

### `app/controllers/`
- **posts_controller.rb** — Trigger AI review on post create/update
- **post_revisions_controller.rb** — Trigger AI review on revision submit
- **admin/posts_controller.rb** — Admin rerun of failed AI reviews

---

## Layer Responsibilities

| Layer | Responsibilities |
|-------|-----------------|
| **Controller Layer** | Detect content changes, enqueue AI review jobs |
| **Job Layer** | Orchestrate moderation pipeline, handle retries |
| **Service Layer** | Configuration, LLM communication, payload building, decision parsing |
| **Model Layer** | State machine, persistence of AI review results, verification logic |
| **Data Layer** | PostgreSQL storage for settings and AI review metadata |

---

## Technologies

| Technology | Usage |
|------------|-------|
| **Ruby on Rails** | Application framework |
| **RubyLLM** | LLM client library (supports OpenAI, Gemini, Claude, Mistral) |
| **Sidekiq** | Background job processing |
| **PostgreSQL** | Database |
| **Active Record Encryption** | Encrypted API key storage |
| **Turbo Streams** | Real-time UI updates for AI review status |
| **Docker** | Containerization (optional Ollama support) |

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `AI_MODERATION_PROVIDER` | AI provider (overrides DB setting) |
| `AI_MODERATION_MODEL` | Model name (overrides DB setting) |
| `AI_MODERATION_AUTO_APPROVE_THRESHOLD` | Confidence threshold (overrides DB) |
| `AI_MODERATION_TIMEOUT_SECONDS` | Request timeout (overrides DB) |
| `AI_MODERATION_MAX_RETRIES` | Max retries (overrides DB) |
| `AI_MODERATION_ENABLED` | Feature toggle (overrides DB) |
| `AI_MODERATION_ADMIN_EMAIL` | Admin email for auto-approval actor |
| `OPENAI_API_KEY` | OpenAI API key |
| `GEMINI_API_KEY` | Google Gemini API key |
| `ANTHROPIC_API_KEY` | Anthropic Claude API key |
| `MISTRAL_API_KEY` | Mistral AI API key |