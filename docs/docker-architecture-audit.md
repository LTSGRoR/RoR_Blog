# Docker architecture audit — 2026-10-08

Scope: Dockerfile, build exclusions, entrypoint, development Compose, production overlay, Caddy, database pools, and Sidekiq commands. Validation used Compose's merged configuration with placeholder secrets and shell syntax checks. No containers were started, rebuilt, stopped, or deployed.

## Architecture

Public HTTPS terminates at Caddy, which forwards to Puma. The web application uses PostgreSQL for application data and Solid Cache/Cable, Redis for Sidekiq, and Elasticsearch for search. The default worker handles chat generation, moderation, broadcasts, and suspension cleanup. A separate two-thread worker handles search indexing and embeddings. Production web/worker containers share the uploaded-file volume; PostgreSQL, Redis, Elasticsearch, and Caddy each have persistent volumes.

This is a reasonable single-host architecture. It does not provide host failover or safe multi-host upload storage.

## Findings fixed in configuration

| Priority | Finding | Change |
| --- | --- | --- |
| High | Default Compose shutdown grace was 10 seconds, shorter than Sidekiq's default 25-second shutdown timeout plus cleanup time. Forced termination risks lost or interrupted work. | Give both worker services 35 seconds to stop; indexing inherits the worker setting in development and in the merged production configuration. |
| Medium | Development web/workers waited for PostgreSQL/Redis containers to start, not for readiness. Production Redis inherited the same weak dependency. | Add PostgreSQL/Redis health checks and require healthy dependencies. |
| Medium | Strict embeddings-first queues could starve search indexing under sustained embedding load. | Change Compose and Kamal commands to weighted searchkick:embeddings queues at 2:1. Weighting improves selection fairness but does not reserve a free thread for search. |
| Medium | Elasticsearch readiness curls accepted HTTP errors, and entrypoint requests had no time limit. | Fail on HTTP errors and bound curl requests. The probe checks HTTP reachability, not complete cluster recovery. |

These settings take effect only when containers are recreated through the normal deployment process. A CLI stop timeout can override the configured grace; do not use a shorter timeout for workers.

References: [Compose services](https://docs.docker.com/reference/compose-file/services/), [startup ordering](https://docs.docker.com/compose/how-tos/startup-order/), [Sidekiq shutdown](https://github.com/sidekiq/sidekiq/wiki/Deployment), [Sidekiq queues](https://github.com/sidekiq/sidekiq/wiki/Advanced-Options).

## Remaining architecture risks

1. **No resource ceilings or container log rotation.** Elasticsearch has a 512 MB Java heap, but that is not a total container memory limit. PostgreSQL, native image processing, Ruby workers, and Elasticsearch compete on the same host. Docker log growth is also unbounded by repository configuration unless the daemon supplies rotation. Establish memory/CPU budgets from host capacity and measured load, and rotate container logs. Arbitrary low caps would create new outages, so none were guessed here.
2. **Web startup performs database maintenance.** The server entrypoint runs `db:prepare` on every boot. This couples health/startup time to migrations and is unsafe to assume as the deployment strategy when scaling web replicas. The existing runbook already calls for paused writes and stopped workers during migration; move migration ownership to an explicit release step when scaling.
3. **AI work and UI broadcasts share the default queue.** Three slow provider calls can occupy all default worker threads and delay comments/broadcasts/cleanup. Split latency-sensitive jobs from AI jobs if queue latency becomes material. Weighted indexing queues do not fix this default-queue bottleneck.
4. **Single-host persistence is not a backup.** Host/storage failure affects the database, queues, uploads, search, and certificates together. The existing backup script covers database/uploads; Redis and Caddy need separate preservation if their state matters. Test off-host restoration regularly. Multiple web hosts require object storage or another shared upload service.
5. **Managed-service mode still depends on bundled services.** Setting external database/Redis/Elasticsearch URLs does not remove Compose dependencies on local services. A dedicated external-infrastructure overlay is needed to avoid running unused containers and requiring the bundled database to be healthy.
6. **Health checks do not provide runtime recovery or alerting.** Startup dependency conditions are not continuous dependency supervision; `restart: unless-stopped` does not restart a container simply because its health check becomes unhealthy. The Rails health endpoint does not prove PostgreSQL/Redis/Elasticsearch or worker queues are healthy. Monitor dependency availability and queue latency separately.
7. **Two app image tags repeat identical builds.** Web and workers build the same Dockerfile under different image names. Reusing one versioned image for all Rails services would reduce build/pull work and make release consistency clearer. Current caching mitigates repeated build work but does not establish an immutable release.
8. **Image and network hardening remain operational work.** Several images use mutable tags, and Elasticsearch is pinned to an old 8.9.0 version. Inventory supported versions and scan images before a staged upgrade; no upgrade or migration was attempted. Production backend ports are unpublished, but services share one Docker network and Elasticsearch security is disabled. Add network isolation/authentication when the threat model or deployment boundary requires it.

## Existing safeguards

Production removes the source bind mount, binds the diagnostic Rails port to loopback, and publishes only Caddy publicly. Backend data ports are removed by the overlay. Redis has AOF persistence, uploads are shared between Rails services, and the image runs as UID 1000. Secrets and local uploaded files are excluded from the build context. Production defaults to HTTPS and disables Solid Queue inside Puma. Database pools of five exceed current worker concurrency of three/two; total connections still grow with process count and Solid adapter pools.

## Validation

Development and merged production Compose configurations parsed successfully using Compose v5.4.0 and placeholder secrets. Assertions verified healthy database/Redis dependencies, 35-second worker shutdown, weighted queue arguments, production backend ports remaining unpublished, loopback web diagnostics, and absence of a production source bind mount. `bash -n bin/docker-entrypoint` and `git diff --check` passed. Live startup, shutdown, image building, memory usage, and dependency outages were not tested because the local Docker daemon is unavailable.
