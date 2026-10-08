# RoR Blog

A Rails 8 community blog application with:

- User authentication with Devise.
- Authorization with Pundit.
- Full-text search with Searchkick + Elasticsearch.
- Background processing with Sidekiq + Redis.
- AI-assisted post moderation via RubyLLM providers (Mistral, OpenAI, Gemini, Claude).
- Hotwire/Turbo UI updates and Tailwind CSS styling.
- Rich text authoring with image resizing, captions, links, and block alignment.
- Revision drafts and admin review before changes reach published posts.

## Tech Stack

- Ruby `3.3.9`
- Rails `8`
- PostgreSQL
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

## Quick Start (Local)

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

## Quick Start (Docker Compose)

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
- Configuration: Set `AI_MODERATION_PROVIDER`, `AI_MODERATION_MODEL`, and provider-specific API keys

## Search

- Search is implemented with Searchkick and Elasticsearch.
- Keep Sidekiq running to process async indexing jobs.
- Docker Compose's `indexing` service consumes the `searchkick` and `embeddings` queues.

If search seems stale locally, verify:

- Redis is running.
- Sidekiq is running.
- Elasticsearch is healthy.

If logs report `Searchkick::InvalidQueryError — Bad mapping — run Post.reindex`,
the existing index does not match the current search configuration. Rebuild it:

```bash
docker compose exec -T -e EMBEDDINGS_AUTO_RUN_ON_BOOT=false app bundle exec rails runner 'Post.reindex'
```

Use `Tag.reindex` as well after changing tag autocomplete mappings. Updating
code or restarting the app does not rebuild existing mappings when
`REINDEX_ON_BOOT=false`.

To rebuild both indexes on every Docker app startup, set this in `.env`:

```dotenv
REINDEX_ON_BOOT=true
```

Then recreate the app container to apply the environment change:

```bash
docker compose up -d --force-recreate app
```

Full reindexing delays startup, especially with large datasets. Keep it disabled
for routine production restarts and run reindexing explicitly after mapping changes.

## Useful Commands

Run tests:

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

## Deployment Notes

- The included `Dockerfile` is production-oriented.
- `kamal` is included for container deployment workflows.
- In production, prefer setting `DATABASE_URL` when available.
- See [production operations](docs/production-operations.md) for the Compose production stack.
- See the [post editor UI audit](docs/post-editor-ui-audit.md) for editor behavior and verification scope.
