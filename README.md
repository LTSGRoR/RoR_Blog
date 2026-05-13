# RoR Blog

A Rails 8 community blog application with:

- User authentication with Devise.
- Authorization with Pundit.
- Full-text search with Searchkick + Elasticsearch.
- Background processing with Sidekiq + Redis.
- AI-assisted post moderation via RubyLLM providers (Mistral, OpenAI, Gemini, Claude).
- Hotwire/Turbo UI updates and Tailwind CSS styling.

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

5. Start the app stack in one command:

```bash
bin/dev
```

`bin/dev` runs:

- Rails server
- Sidekiq
- Tailwind watch process

App default URL: `http://localhost:3000`

## Quick Start (Docker Compose)

Start all services (app, sidekiq, postgres, redis, elasticsearch):

```bash
docker compose up --build
```

Then prepare the DB (in another shell):

```bash
docker compose exec app bin/rails db:prepare
```

By default, app ports are exposed on `80` and `3000`.

## Core Environment Variables

- `APP_HOST` (default: `localhost`)
- `APP_PORT` (default: `3000`)
- `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD`, `DB_NAME`
- `REDIS_URL` (default: `redis://redis:6379/0` in compose)
- `ELASTICSEARCH_URL` (default compose: `http://elasticsearch:9200`)
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

If search seems stale locally, verify:

- Redis is running.
- Sidekiq is running.
- Elasticsearch is healthy.

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

## Deployment Notes

- The included `Dockerfile` is production-oriented.
- `kamal` is included for container deployment workflows.
- In production, prefer setting `DATABASE_URL` when available.
