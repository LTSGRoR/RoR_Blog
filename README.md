# RoR Blog

A Rails 8 community blog application with:

- User authentication with Devise.
- Authorization with Pundit.
- Full-text search with Searchkick + Elasticsearch.
- Background processing with Sidekiq + Redis.
- AI-assisted post moderation via RubyLLM providers (Mistral, OpenAI, Gemini, Claude).
- A blog reading assistant with semantic retrieval, scope checks, and prompt-injection safeguards.
- Hotwire/Turbo UI updates and Tailwind CSS styling.
- Rich text authoring with image resizing, captions, links, and block alignment.
- Revision drafts and admin review before changes reach published posts.

## Tech Stack

- Ruby `3.3.9`
- Rails `8.1`
- PostgreSQL with pgvector (Compose uses PostgreSQL `16`)
- Redis
- Sidekiq + sidekiq-cron
- Elasticsearch `8.x`

## Supported Locales

This app routes localized pages under `/:locale` and currently supports:

- `en`
- `vi`
- `ja`

The blog feed is available at `/en/blog`, `/vi/blog`, and `/ja/blog`. Editor
toolbars, image caption prompts, thumbnail controls, and authoring messages follow
the selected locale. Clicking a tag filters the feed and shows a translated
heading such as “All Ruby Posts,” with the tag's first letter capitalized.

## Post Editor

- Shared editing and reading styles, including light code panels and plain monospace text.
- Left, center, and right block alignment.
- Image resizing by dragging the corner handle; arrow keys provide fine adjustments.
- Centered image captions and thumbnail upload controls.
- A link dialog for inserting, editing, and removing links while preserving formatting.
- Links in rendered post content open in a new tab or window.

## Account Restrictions and Content

- Banning a user hides their posts from public pages, search, and recommendations.
  Their comments become placeholders, retaining replies from other users.
- Unbanning restores content according to its existing publication and verification status.
- Suspension leaves existing posts visible but hides comments until the suspension
  expires or an admin removes it.
- Reactions from banned or suspended users are excluded from counts and rankings;
  they reappear when the restriction ends.
- Hidden comments cannot receive new replies or reactions. Existing replies remain readable.
- Content is preserved; account restrictions do not delete it or change post verification.
  Admins can still open banned users' posts for review.

Existing open pages reflect restrictions on their next request or refresh.

## Production Operations

The production stack uses both `docker-compose.yml` and `docker-compose.prod.yml`.
Caddy handles public HTTPS on ports `80` and `443`; Rails binds its diagnostic port
to `127.0.0.1:3000`. PostgreSQL, Redis, and Elasticsearch have no published production ports.
Uploads use the shared `blog_storage` volume; workers are split between the
`sidekiq` service (`default`) and `indexing` service (`embeddings`, `searchkick`).

For an existing deployment, keep its current Compose project name and production
env file. Changing the project name can select different named volumes. The
development quick-start commands below are for a separate development environment.

Read-only status and log checks (replace `existing-project` and the env-file path
with the values already used by your deployment):

```bash
docker compose -p existing-project --env-file /path/to/production.env -f docker-compose.yml -f docker-compose.prod.yml ps
docker compose -p existing-project --env-file /path/to/production.env -f docker-compose.yml -f docker-compose.prod.yml logs --tail=100 app sidekiq indexing
```

Production requires a concrete `APP_HOST`, a strong `DB_PASSWORD`, the three
`ACTIVE_RECORD_ENCRYPTION_*` values, and `SECRET_KEY_BASE` or `RAILS_MASTER_KEY`.
Preserve existing encryption keys when upgrading so saved provider credentials
remain readable. Use `PROD_DATABASE_URL`, `PROD_REDIS_URL`, and
`PROD_ELASTICSEARCH_URL` for managed infrastructure; Compose does not use the
host-side `DATABASE_URL` as its production connection override.

Keep `REINDEX_ON_BOOT=false` for routine production starts. The server entrypoint
runs `db:prepare`; migrations and worker compatibility must be planned before
recreating containers. Production seeds do not provision users. The
`admin:provision` task creates a new administrator from securely supplied
`ADMIN_EMAIL`, `ADMIN_NAME`, and `ADMIN_PASSWORD` values without overwriting an
existing account.

Use the [production operations guide](docs/production-operations.md) for deployment,
backups, isolated restore checks, and maintenance. Back up the database and uploads
before upgrades, and test restoration away from the live database. Do not run
development seeds, test suites, or restore exercises against production data.

## Quick Start (Local Development)

1. Install dependencies:
	 - Ruby `3.3.9`
	 - PostgreSQL
	 - Redis
	 - Elasticsearch 8
2. Install gems:

```bash
bundle install
```

3. Configure environment values (shell export or `.env` via dotenv):

Generate Active Record encryption keys once with:

```bash
bin/rails db:encryption:init
```

```bash
export DB_HOST=localhost
export DB_USERNAME=postgres
export DB_PASSWORD=postgres
export REDIS_URL=redis://localhost:6379/0
export ELASTICSEARCH_URL=http://localhost:9200
export AI_MODERATION_PROVIDER=mistral
export AI_MODERATION_MODEL=mistral-small-latest
export MISTRAL_API_KEY=your_mistral_api_key
export ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=your_primary_key
export ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=your_deterministic_key
export ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=your_key_derivation_salt
```

4. Prepare database:

```bash
bin/rails db:prepare
```

With Elasticsearch running, create the search indexes:

```bash
bin/rails runner 'Tag.reindex; Post.reindex'
```

5. Start the app stack in one command:

```bash
bin/dev
```

`bin/dev` runs:

- Rails server
- Sidekiq
- Tailwind watch process

App default URL: `http://localhost:3000`

Embedding jobs use a separate queue. To process them locally, also run:

```bash
bundle exec sidekiq -q embeddings
```

## Quick Start (Development Docker Compose)

Copy `.env.example` to `.env` and configure the required values, including the
Active Record encryption keys above. Start all services (app, Sidekiq workers,
PostgreSQL, Redis, and Elasticsearch):

```bash
docker compose up --build
```

The app entrypoint prepares the database. Once the services are running, create
the search indexes (in another shell):

```bash
docker compose exec -T -e EMBEDDINGS_AUTO_RUN_ON_BOOT=false app bundle exec rails runner 'Tag.reindex; Post.reindex'
```

By default, app ports are exposed on `80` and `3000`.

Compose supplies container service URLs. For host-side commands, use `localhost`
for PostgreSQL, Redis, and Elasticsearch instead of Docker service names.

## Core Environment Variables

- `APP_HOST` (default: `localhost`)
- `APP_PORT` (default: `3000`)
- `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD`, `DB_NAME`
- `REDIS_URL` (default: `redis://redis:6379/0` in compose)
- `ELASTICSEARCH_URL` (default compose: `http://elasticsearch:9200`)
- `REINDEX_ON_BOOT` (default: `false`; Docker app startup rebuilds both search indexes when `true`)
- `AI_MODERATION_PROVIDER` (supported: mistral, openai, gemini, claude)
- `AI_MODERATION_MODEL` (e.g., mistral-small-latest)
- `MISTRAL_API_KEY` (required if using Mistral provider)
- `OPENAI_API_KEY`, `GEMINI_API_KEY`, `ANTHROPIC_API_KEY` (for the corresponding providers)
- `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`, `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`
- `AI_CHAT_USER_HOURLY_LIMIT` (default: `20`), `AI_CHAT_USER_PENDING_LIMIT` (default: `2`), `AI_CHAT_DAILY_LIMIT` (default: `500`)
- `AI_CHAT_MIN_POST_SIMILARITY` (default: `0.35`)
- `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_DOMAIN`, `SMTP_USERNAME`, `SMTP_PASSWORD`
- `FORCE_SSL` (production, default true)

## Background Jobs and Scheduling

- Active Job adapter is Sidekiq in development and production.
- Sidekiq cron entries are loaded from `config/sidekiq_schedule.yml`.
- Current recurring task:
	- `ClearExpiredSuspensionsWorker` every minute.

Admin users can access Sidekiq Web UI at `/sidekiq`.

## AI Moderation

AI moderation is driven by background jobs and configurable moderation settings.

- New post moderation job: `ModeratePostJob`
- Provider integration: `AiModeration::Client`
- Supported providers: Mistral, OpenAI, Gemini, Claude (via RubyLLM)
- Revision moderation job: `ModeratePostRevisionJob`
- Admin AI settings configure review instructions, model/provider, thresholds, and credentials.
- Nonblank `AI_MODERATION_*` environment overrides take precedence over the corresponding saved settings.
- An encrypted API key saved by an admin takes precedence over the provider's environment API key.

## Blog Reading Assistant

- Explains, summarizes, compares, and recommends available blog posts.
- Explains code already present in a supplied post; refuses new code generation,
  standalone math, article composition, and unrelated general-purpose questions.
- Uses pgvector embeddings for relevant posts and conversation context. Claude
  generation is supported, but the current embedding service supports OpenAI,
  Gemini, and Mistral only.
- Loads the latest admin-edited assistant prompt for each new request and sends it
  as actual system instructions. Admins can adjust tone and blog-specific guidance;
  the fixed reading scope and injection safeguards stay active.
- Keeps user questions, retrieved posts, and conversation history separate as
  untrusted data. Request and response checks run before an answer is published.
- Rejected requests/answers receive a translated scope message without recommendation
  cards or saved embeddings, and are excluded from later conversation context.
- Invalid policy decisions fail closed. Provider failures return the existing
  unavailable message instead of publishing an unchecked answer.

Allowed substantive requests make two additional model calls for scope and
response checks, increasing latency and provider usage. These are layered defenses,
not a guarantee against every prompt injection. Request admission limits are not
provider spending caps; queued requests expire after ten minutes.

See [assistant scope and security](docs/assistant-security.md) for the request flow,
admin prompt behavior, and evaluation coverage.

## Search

- Search is implemented with Searchkick and Elasticsearch.
- Keep Sidekiq running to process async indexing jobs.
- Docker Compose's `indexing` service consumes the `searchkick` and `embeddings` queues.

If search seems stale locally, verify:

- Redis is running.
- Sidekiq is running.
- Elasticsearch is healthy.

If logs report `Searchkick::InvalidQueryError — Bad mapping — run Post.reindex`,
the existing index does not match the current search configuration. In development,
rebuild it with:

```bash
docker compose exec -T -e EMBEDDINGS_AUTO_RUN_ON_BOOT=false app bundle exec rails runner 'Post.reindex'
```

Use `Tag.reindex` as well after changing tag autocomplete mappings. Updating
code or restarting the app does not rebuild existing mappings when
`REINDEX_ON_BOOT=false`.

For development only, to rebuild both indexes on every Docker app startup, set
this in your development `.env`:

```dotenv
REINDEX_ON_BOOT=true
```

Then recreate the app container to apply the environment change:

```bash
docker compose up -d --force-recreate app
```

Full reindexing delays startup, especially with large datasets. Keep it disabled
for routine production restarts. Production reindexing is an explicit maintenance
operation using the existing project's production Compose configuration; see the
[operations guide](docs/production-operations.md).

## Useful Commands

Run tests against an isolated test database and test search indexes. The test
`DATABASE_URL` must point to a test database such as `ror_blog_test`:

```bash
bin/rails test
```

Run RuboCop:

```bash
bin/rubocop
```

Run Brakeman:

```bash
bin/brakeman
```

Run Rails console:

```bash
bin/rails console
```

Run the editor's database-independent storage/rendering checks:

```bash
bundle exec ruby test/models/action_text_alignment_test.rb
bundle exec ruby test/models/action_text_image_dimensions_test.rb
bundle exec ruby test/models/action_text_links_test.rb
```

Editor browser checks live in `test/javascript/` and require Playwright and
Chromium. For example:

```bash
node test/javascript/editor_localization.cjs
```

Run assistant policy and admin-prompt regression checks in the test environment:

```bash
bundle exec ruby test/models/assistant_policy_test.rb
bin/rails test test/jobs/assistant_scope_test.rb test/jobs/chat_generation_test.rb test/integration/assistant_prompt_settings_test.rb
```

An optional live assistant evaluation is available for a development/staging
environment with the configured provider. It makes API requests and incurs usage;
it does not create or change users, settings, or chat records:

```bash
bin/rails runner test/scripts/assistant_security_eval.rb
```

## Deployment Notes

- The included `Dockerfile` is production-oriented.
- `kamal` is included for container deployment workflows.
- In custom production deployments, Rails supports `DATABASE_URL`; the included
  Compose production overlay uses `PROD_DATABASE_URL` to override its internal URL.
- See [production operations](docs/production-operations.md) for the Compose production stack.
- See the [post editor UI audit](docs/post-editor-ui-audit.md) for editor behavior and verification scope.
- See the [account restrictions verification](docs/account-restrictions-ui-audit.md) for content visibility and UI checks.
