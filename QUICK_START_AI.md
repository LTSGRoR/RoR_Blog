# Quick Start Guide - AI Feedback Suggestions

Get the AI-powered feedback suggestion system up and running in 5 minutes.

## Prerequisites

- Docker and Docker Compose installed
- Git cloned repository
- ~20GB disk space for Ollama models (first time only)

## Step-by-Step Setup

### 1. Configure Environment (1 min)

```bash
cd /Users/bob/Work/Blog/ror_blog

# Copy example environment file
cp .env.example .env

# No changes needed to .env for local development (defaults are fine)
```

### 2. Start Docker Services (1-2 min)

```bash
# Start all services
docker-compose up -d

# Wait for PostgreSQL to be ready
docker-compose exec app bin/rails db:create

# Run migrations
docker-compose exec app bin/rails db:migrate
```

### 3. Install Ollama Models (3-5 min + download time)

```bash
# Install embedding model
docker-compose exec ollama ollama pull nomic-embed-text

# Install LLM model
docker-compose exec ollama ollama pull gemma:4b

# Verify models are installed
docker-compose exec ollama ollama list
```

### 4. Test Setup (1 min)

```bash
# Test Ollama API
curl http://localhost:11434/api/tags
# Should return: {"models":[{"name":"gemma:4b:latest",...},{"name":"nomic-embed-text:latest",...}]}

# Test PostgreSQL pgvector extension
docker-compose exec ror_blog_db psql -U postgres -d ror_blog_development \
  -c "SELECT 1 FROM post_revisions LIMIT 1"
# Should not error (pgvector is installed)

# Check that Sidekiq is running
docker-compose ps sidekiq
# Should show "Up"
```

### 5. Create Test Data (optional)

```bash
# Enter Rails console
docker-compose exec app bin/rails console

# Create test post revision (if not exists)
user = User.first || User.create!(name: "Admin", email: "admin@test.com", encrypted_password: "test123")
post = Post.first || Post.create!(title: "Test Post", user: user, body: "Test content", status: :published)
revision = PostRevision.create!(
  post: post,
  author: user,
  title: "Edited Post",
  body: "Edited content"
)

# Reject it to trigger embedding generation
revision.reject!(admin: user, note: "Needs more citations and sources")
# => Sidekiq job queued to generate embedding

# Wait a few seconds for embedding to generate, then check
sleep 5
revision.reload.embedding.present?
# => true
```

## Using AI Suggestions

### Via cURL/API

```bash
# Generate suggestions for a rejected revision
curl -X POST http://localhost:3000/admin/post_revisions/1/generate_feedback_suggestions \
  -H "Content-Type: application/json" \
  -H "Cookie: session_id=your_admin_session"

# Response:
# {
#   "suggestions": [
#     "Consider adding more specific citations to support your arguments.",
#     "The introduction could be more compelling.",
#     "Break up long paragraphs into shorter, more readable sections."
#   ],
#   "similar_count": 3,
#   "cached": false,
#   "generated_at": "2026-05-07T12:00:00Z",
#   "revision_id": 1
# }
```

### Via Rails Console

```bash
docker-compose exec app bin/rails console

revision = PostRevision.where(moderation_status: :rejected).first
suggestions = PostRevisionFeedbackService.generate_suggestions!(revision)
puts suggestions[:suggestions]
```

## Monitoring & Debugging

### Check Service Status

```bash
# All services
docker-compose ps

# Logs for each service
docker-compose logs app          # Rails app
docker-compose logs sidekiq      # Background jobs
docker-compose logs ollama       # LLM server
docker-compose logs ror_blog_db  # PostgreSQL
docker-compose logs redis        # Redis cache
```

### Monitor Performance

```bash
# Watch Docker resource usage
docker stats

# Check Ollama performance
docker-compose exec ollama curl -s http://localhost:11434/api/generate \
  -d '{"model":"gemma:4b","prompt":"test","stream":false}' | head -c 200
```

### Database Queries

```bash
# Enter PostgreSQL CLI
docker-compose exec ror_blog_db psql -U postgres -d ror_blog_development

# Check embeddings
SELECT id, embedding_generated_at, moderation_status FROM post_revisions WHERE embedding IS NOT NULL;

# Check pgvector index
SELECT * FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'post_revisions';

# Check vector similarity
SELECT id, embedding <=> (SELECT embedding FROM post_revisions LIMIT 1) as distance 
FROM post_revisions WHERE embedding IS NOT NULL LIMIT 5;
```

## Stopping Services

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (reset database)
docker-compose down -v
```

## Common Issues

### Issue: "Connection refused" to Ollama

**Solution**: Ollama might still be downloading models. Check logs:
```bash
docker-compose logs -f ollama
```

Wait until you see: `"status":"success"` message for both models.

### Issue: Suggestion generation times out

**Solution**: Ollama model might be processing. Try again or:
```bash
# Increase timeout in .env
AI_SUGGESTION_TIMEOUT=120

# Restart app
docker-compose restart app
```

### Issue: "Model not found" error

**Solution**: Models not installed. Run:
```bash
docker-compose exec ollama ollama pull nomic-embed-text
docker-compose exec ollama ollama pull gemma:4b
```

### Issue: Embeddings not generating

**Solution**: Check Sidekiq is running and processing jobs:
```bash
# Check Sidekiq is up
docker-compose ps sidekiq

# Check for errors
docker-compose logs sidekiq

# Manually retry
docker-compose exec app bin/rails runner \
  "PostRevisionEmbeddingJob.new.perform(1)"
```

## Next Steps

1. **Integrate UI**: Add "Get AI Suggestions" button to admin moderation page
2. **Test at scale**: Create multiple rejected posts to test similarity search
3. **Monitor costs**: Track API calls and embedding generation time
4. **Customize models**: Try different Ollama models for speed/quality tradeoff

## Resources

- Full documentation: `docs/AI_FEEDBACK_SUGGESTIONS.md`
- Ollama models: https://ollama.ai/library
- Architecture details: See plan in repository session notes

## Support

If something doesn't work:

1. Check logs: `docker-compose logs`
2. Check service status: `docker-compose ps`
3. Check resources: `docker stats`
4. Try restarting: `docker-compose restart`
5. Review full docs: `docs/AI_FEEDBACK_SUGGESTIONS.md`
