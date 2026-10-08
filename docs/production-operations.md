# Production operations

The production Compose overlay includes Caddy for automatic HTTPS. Set a concrete `APP_HOST` whose DNS points at this server and allow public ports 80 and 443. The Rails diagnostic port binds only to loopback. PostgreSQL, Redis and Elasticsearch have no published production ports. Do not expose their container network to untrusted workloads.

## Apply the audit fixes

1. Back up the database and uploaded files before upgrading. Keep your production environment file outside the image and out of Git. Use a separate production env file rather than the development `.env`; set a strong `DB_PASSWORD`, production `DB_NAME`, SMTP settings and the encryption/secret values described in `.env.example`.
2. Build: `docker compose --env-file /path/to/production.env -f docker-compose.yml -f docker-compose.prod.yml build`.
3. With writes paused and workers stopped, migrate using the new image: `docker compose --env-file /path/to/production.env -f docker-compose.yml -f docker-compose.prod.yml run --rm --no-deps app bundle exec rails db:prepare`. The new migration adds optimistic locking, AI review tokens and an index for chat admission limits. The job and model changes require this migration before workers resume.
4. Start the updated stack: `docker compose --env-file /path/to/production.env -f docker-compose.yml -f docker-compose.prod.yml up -d`.
5. Explicitly rebuild search once to remove historical stale documents: `docker compose --env-file /path/to/production.env -f docker-compose.yml -f docker-compose.prod.yml exec app bundle exec rails runner 'Tag.reindex; Post.reindex'`. Routine restarts no longer reindex. This command may take time on a large database.
6. Verify HTTPS, authentication, mail delivery and background processing. In-flight pre-upgrade reviews should be rerun; changed review snapshots now go to manual review rather than approving stale content.

The development services are not restarted by these repository changes. Existing production administrators created by old seeds retain their existing password until it is rotated. Rotate those passwords through the password recovery/account settings flow before enabling public traffic. Seeds now skip production entirely. Create a new administrator with `admin:provision` and `ADMIN_EMAIL`, `ADMIN_NAME` and `ADMIN_PASSWORD` provided through a secure environment. The task refuses to overwrite an existing account and requires a password of at least 12 characters. Do not paste passwords into command history.

Redis uses AOF persistence with a named volume and one-second fsync. Recreating the previous nonpersistent Redis container cannot recover historical jobs; drain its queue before replacing it. Sidekiq owns Active Job execution and suspension cleanup. The production stack no longer starts Solid Queue inside Puma.

Assistant admission limits default to 20 requests per user per hour, two pending requests per user, and 500 accepted requests per deployment per day. Configure `AI_CHAT_USER_HOURLY_LIMIT`, `AI_CHAT_USER_PENDING_LIMIT` and `AI_CHAT_DAILY_LIMIT` to match your provider budget. Zero disables admission. These are request limits, not a monetary spending guarantee; configure the provider's spending cap too. Queued chats expire after ten minutes. Failed requests count toward limits.

For managed infrastructure, use `PROD_DATABASE_URL`, `PROD_REDIS_URL` and `PROD_ELASTICSEARCH_URL`. URL credentials must be percent encoded. Custom deployments may override the bundled infrastructure dependencies. Uploaded files currently use local shared Docker storage; multiple hosts need shared object storage before scaling.

## Backup and restore

Schedule `bin/backup-production /secure/backup/path` from the repository with `PRODUCTION_ENV_FILE=/path/to/production.env`. For the bundled database, the script creates a private directory with a timestamped PostgreSQL custom-format dump and uploaded-file archive, and refuses concurrent runs. For managed PostgreSQL, use the provider's snapshot/backup facility; the script refuses to back up the unrelated bundled database. For a mutually consistent database/file backup, pause writes and drain/stop workers first. Database snapshots are consistent, but the script cannot atomically snapshot filesystem uploads. Copy backups to encrypted off-host storage, apply your retention policy, and periodically test restoration into an isolated environment. It does not delete old backups.

For restore, keep the target app and workers stopped, restore the custom dump with `pg_restore` into an **empty isolated database**, and extract `storage.tar.gz` into that environment's storage volume as the Rails UID (1000). Never test restore against a running production database. Bring up the target stack, verify attachment downloads and sign-in, then rebuild search indexes. Back up Redis/Caddy volumes separately if preserving queued jobs/certificates is required. Restoring database/uploads does not restore pending jobs.

## Regression checks

Set `RAILS_ENV=test`, `DATABASE_URL=postgresql://.../ror_blog_test` and `ELASTICSEARCH_URL` in the test process environment. Run `bin/rails db:test:prepare`, then `bin/rails test` and `bin/rails test:system` against isolated services. Browser tests use headless Chrome. CI provisions pgvector PostgreSQL and Elasticsearch and checks Ruby advisories, Brakeman and lint. Test jobs use the test adapter and do not send AI or mail requests.

## Background job failures

Check the admin-only `/sidekiq` page for Retries and Dead jobs as well as the queue sizes. An empty queue does not prove that all jobs succeeded. Rendering jobs run without a browser session: broadcast partials must not assume Devise's Warden proxy or a current user exists. Shared streams must also avoid viewer-specific markup.

Moderation table updates are enqueued as separate Turbo broadcast jobs so rendering failures can retry independently of account updates and suspension cleanup. AI chat broadcasts retain their polling fallback; their handled failures are reported through `Rails.error` as well as logged. Sidekiq failures are forwarded to `Rails.error` with job class, ID, and queue, without copying job arguments into the error context.

Automatic alerts require a configured Rails error subscriber or external monitoring of Sidekiq Retries/Dead jobs. The reporting hooks alone do not send alerts. After deploying these changes through the normal process, verify monitoring with an intentional failure in staging, rather than introducing a failed job into production.

The rendering regression tests cover comment replies, moderation states, user status rows, chat responses, and lazy thumbnail URLs without a Warden session. Run `bundle exec ruby test/models/background_broadcast_rendering_test.rb` and `bundle exec ruby test/models/comment_reply_broadcast_rendering_test.rb`; the database-backed broadcast integration coverage is in `test/jobs/comment_broadcast_test.rb`.
