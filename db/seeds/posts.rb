# Explicit authors keep ownership stable when the user list changes.
DEMO_POSTS = [
  {
    author: "Tienbob", legacy_title: "Getting Started with Hotwire in Rails 8",
    title: "Building a Rails Blog: From Request to Published Post",
    tags: %w[rails ruby architecture],
    body: <<~HTML
      <h2>Start with a complete feature</h2>
      <p>A blog is a useful way to learn Rails because one feature crosses routes, controllers, models, and views. Begin with creating a draft, displaying validation errors, and publishing it. Keep authentication and authorization visible in that flow rather than adding them after the interface is finished.</p>
      <h2>Make ownership part of the query</h2>
      <p>Build posts through the signed-in user's association. Never accept user_id from a submitted form. When editing, find the record through that same association so another author's ID cannot grant access.</p>
      <pre><code class="language-ruby">def create
        @post = current_user.posts.build(post_params)
        @post.status = :draft
        if @post.save
          redirect_to @post, status: :see_other
        else
          render :new, status: :unprocessable_entity
        end
      end

      def post_params
        params.require(:post).permit(:title, :body)
      end</code></pre>
      <h2>Separate writing from publication</h2>
      <p>A valid draft is not necessarily ready for readers. Represent publication as an explicit state transition, and check the actor's permissions on the server. In a moderated blog, the public query should require both published status and approval. A hidden button alone is not an access control.</p>
      <h2>Check the complete journey</h2>
      <p>Test that an author can save a draft, cannot edit another author's post, and sees useful errors for a blank title. Verify that an unapproved post never appears in the public listing. These tests protect the behavior readers and authors rely on, even when controller internals change.</p>
      <p>Extend the feature only after this path works: add tags, rich text, and background indexing as separate changes with clear responsibilities.</p>
    HTML
  },
  {
    author: "Long", legacy_title: "Mastering ActiveRecord Performance",
    title: "Fixing Slow Rails Lists with Active Record",
    tags: %w[rails postgresql performance],
    body: <<~HTML
      <h2>Measure the page before changing it</h2>
      <p>A post list can look simple while executing a query for every author and every set of tags. Inspect development SQL logs with a realistic number of records. Record the number of queries and response time before optimizing so you can tell whether the change helped.</p>
      <h2>Load the associations the view uses</h2>
      <pre><code class="language-ruby">@posts = Post.where(status: :published, verified: true)
        .includes(:user, :tags)
        .order(created_at: :desc, id: :desc)
        .limit(20)</code></pre>
      <p>The view can now read post.user.name and iterate post.tags without repeatedly fetching those associations. Avoid calling post.tags.pluck(:name) inside that loop: it can issue fresh SQL even when the association was loaded. Use post.tags.map(&amp;:name) for the loaded records.</p>
      <h2>Choose indexes from the actual query</h2>
      <p>Use explain to inspect the query plan. A candidate index for this list covers status, verified, created_at, and id, but check selectivity and the database plan before adding it. Indexes consume space and add work to writes; indexing every column is not a performance strategy.</p>
      <h2>Bound the work</h2>
      <p>Use pagination rather than rendering the entire table. For large feeds, cursor pagination over created_at and id avoids increasingly expensive offsets and gives tied timestamps a stable order. Use find_each for background batch processing when display order is not required.</p>
      <h2>Verify the improvement</h2>
      <p>Compare logs and timings again with the same dataset. Check that query count stays roughly constant when the page grows from five to twenty posts. Also confirm that approval filters still apply: returning fewer queries is only useful if the page returns the correct records.</p>
      <p>Reference: <a href="https://guides.rubyonrails.org/active_record_querying.html">Active Record Query Interface</a>.</p>
    HTML
  },
  {
    author: "Quy", legacy_title: "Sidekiq: Background Jobs Done Right",
    title: "Reliable Background Work in Rails with Active Job",
    tags: %w[rails sidekiq redis],
    body: <<~HTML
      <h2>Move slow work out of the request</h2>
      <p>Sending email or calling an external service during a form submission ties the response to another system's availability. Save the user's change first, then enqueue the slow work. Active Job provides a Rails interface; configure a persistent backend such as Sidekiq for work that must survive a process restart.</p>
      <pre><code class="language-ruby">class NotifyAuthorJob &lt; ApplicationJob
        queue_as :default
        discard_on ActiveRecord::RecordNotFound

        def perform(post_id)
          post = Post.find(post_id)
          return unless post.published? &amp;&amp; post.verified?
          AuthorMailer.published(post).deliver_now
        end
      end</code></pre>
      <p>Enqueue NotifyAuthorJob.perform_later(post.id) after the publishing transaction commits. The job loads current state, so a post withdrawn before execution will not trigger the notification. The mailer shown here is an application component you need to implement.</p>
      <h2>Expect repeated execution</h2>
      <p>A worker can fail after the email provider accepts a request but before the queue records completion. Retries can therefore send twice. For important side effects, store a delivery record with a unique event key and use the provider's idempotency feature when available. A simple sent_at flag alone does not close every failure window.</p>
      <h2>Retry deliberately</h2>
      <p>Distinguish temporary timeouts from invalid input. Bound retries and external request timeouts. Active Job and the backend may both retry, so inspect their combined behavior before choosing a policy. Missing records can usually be discarded; persistent configuration errors need attention rather than endless retries.</p>
      <h2>Operate the queue</h2>
      <p>Watch queue age and failed jobs, not just worker uptime. Keep expensive indexing work in a separate queue so it cannot delay user notifications. Test stale records and duplicate executions as well as the happy path.</p>
      <p>Reference: <a href="https://guides.rubyonrails.org/active_job_basics.html">Active Job Basics</a>.</p>
    HTML
  },
  {
    author: "Manh", legacy_title: "Elasticsearch with Searchkick: Full-Text Search in Rails",
    legacy_titles: [ "Building a Useful Search Page in Rails" ],
    title: "Ruby and Rails Deep Dive: Designing a Consistent Search Pipeline",
    tags: %w[rails ruby elasticsearch architecture performance testing],
    body: <<~HTML
      <h2>Define what readers may find</h2>
      <p>A public search page should expose the same records as the public feed. For a moderated blog, that means published and verified posts. Put these restrictions in the search query, rather than filtering a page of results afterward and producing misleading totals.</p>
      <pre><code class="language-ruby">query = params[:q].to_s.strip.first(200)
      @posts = Post.search(
        query.presence || "*",
        fields: ["title^3", "body", "tags"],
        where: { status: Post.statuses.fetch("published"), verified: true },
        page: params[:page], per_page: 20
      )</code></pre>
      <p>This Searchkick example assumes title, body, tags, status, and verified are present in the indexed document. The title boost favors direct matches, but relevance should be checked against real reader questions rather than tuned by intuition alone.</p>
      <h2>Keep the index consistent</h2>
      <p>Index creation, body edits, tag changes, publication, and unpublication. Rich text and join tables can change without a normal title update, so check those paths explicitly. Queue indexing after a successful commit. Treat the database as the source of truth and make a full rebuild an explicit maintenance operation.</p>
      <h2>Handle an unavailable search service</h2>
      <p>Show a clear temporary failure message, or use a bounded database fallback with the same visibility restrictions. Do not silently return every post when the search engine fails. Keep result URLs and titles usable with keyboard navigation.</p>
      <h2>Evaluate quality</h2>
      <p>Create a small list of expected queries: exact titles, common Rails terms, misspellings, and phrases that should return nothing. Check both ranking and authorization. Also test an approved post that becomes private while the index is stale; recheck visibility before rendering sensitive records.</p>
      <h2>Design a Ruby boundary you can reason about</h2>
      <p>Keep HTTP parameters outside the indexing layer. Pass explicit keyword arguments to a small service and inject its external dependencies. Ruby's duck typing lets a production client and a deterministic test fake share the same call contract without inheriting from a common framework class. Document what that contract returns and which failures it raises; implicit behavior is harder to operate than a small explicit interface.</p>
      <pre><code class="language-ruby">class SearchDocument
        def self.build(post)
          {
            id: post.id,
            title: post.title.to_s.dup.freeze,
            body: post.body.to_plain_text.freeze,
            tags: post.tags.map { |tag| tag.name.dup.freeze }.sort.freeze,
            visible: post.published? &amp;&amp; post.verified?
          }.freeze
        end
      end</code></pre>
      <p>Freezing a hash is shallow: its strings and arrays remain mutable unless you freeze them too. This snapshot freezes the nested values it constructs, and duplicates model-backed strings before freezing them. It is an example payload builder, not a replacement for this application's Searchkick schema. Avoid memoizing it across requests: a cached document can outlive an approval change.</p>
      <h2>Know when Ruby executes SQL</h2>
      <p>An Active Record relation describes a query until an operation materializes it. Iteration loads model objects; pluck asks the database for selected values; converting a relation into an array shifts subsequent filtering into Ruby. For an indexing batch, preload the author and tags, then extract rich text deliberately. A low SQL count does not guarantee low memory use when each record contains a long article.</p>
      <p>Measure allocations and batch memory alongside database time. Avoid loading an entire corpus into one array. Choose a batch size using realistic body lengths, and bound the payload size sent to the search engine. A worker that is fast for a hundred short posts may fail on a thousand large ones.</p>
      <h2>Serialize conflicting publication changes</h2>
      <p>Imagine one administrator approves a post while another withdraws it. Reading state, deciding, and saving in separate steps allows both decisions to use stale data. A row lock can serialize the critical section. Acquire it before changing attributes, keep it short, and do not make network requests while holding it.</p>
      <pre><code class="language-ruby">post.with_lock do
        raise "Admin required" unless actor.admin?
        post.verify!(actor)
      end</code></pre>
      <p>This example uses this blog's verify! method, which rejects draft posts. with_lock reloads the persisted record under a database lock and wraps the block in a transaction. All competing state transitions must follow the same locking discipline. For a human edit form, optimistic locking with a lock_version column may instead be preferable because it can report a conflict rather than silently replacing another edit.</p>
      <h2>Close the commit-to-queue failure window</h2>
      <p>An after_commit callback avoids indexing a transaction that later rolls back. It does not make a database commit and a Redis enqueue atomic: the process can stop between them. If search consistency matters, write an outbox event in the same database transaction as the state change. A separate dispatcher reads pending events and delivers them with retries.</p>
      <p>The outbox needs an event ID, post ID, revision or content digest, delivery state, and a unique constraint for the chosen event identity. Claim work safely when several dispatchers run. Mark delivery only after the destination acknowledges it. A crash after delivery but before marking completion produces a duplicate, so the consumer still has to tolerate repeated events. These tables and workers are design extensions, not components already supplied by Rails.</p>
      <h2>Handle stale and reordered jobs</h2>
      <p>A delayed job may contain an old approved snapshot after a newer withdrawal. Prefer jobs carrying a post ID that rebuild from current committed state. Two workers can still read different revisions and finish in the opposite order, so use per-post serialization or destination-side version checks when strict ordering matters. Define deletion behavior explicitly: a missing source record should remove its indexed document rather than fail forever.</p>
      <p>Rich text, tags, and approval all contribute to the document. A fingerprint over their canonical values can identify meaningful content changes, but a digest alone does not provide ordering. Keep a monotonic revision if the consumer needs to reject older writes. Reconcile database records and index documents periodically to repair missed events.</p>
      <h2>Make failure observable and testable</h2>
      <p>Record event ID, post ID, revision, attempt count, and latency. Monitor the age of the oldest pending event: workers can be healthy while the backlog grows. Use bounded retries with jitter for transient failures and a visible failed-event queue for malformed payloads. Keep article text and credentials out of routine error logs.</p>
      <p>Test rollback without an event, duplicate delivery, withdrawal during indexing, and older writes arriving last. Exercise concurrency with separate database connections and synchronization barriers rather than arbitrary sleeps. Inject a client that fails before acknowledgment and one that succeeds before the dispatcher crashes. Verify the final document and public visibility, not merely that a method was called.</p>
      <h2>Choose complexity from the requirement</h2>
      <p>A small internal blog may accept a short indexing delay with after-commit jobs and a repair task. A large publication workflow may justify an outbox and versioned writes. State the tolerated delay, recovery process, and privacy boundary before selecting the design. Always recheck current visibility when serving sensitive results; an eventually consistent index should not decide access rights.</p>
      <p>References: <a href="https://guides.rubyonrails.org/active_record_querying.html">Active Record queries</a>, <a href="https://guides.rubyonrails.org/active_record_callbacks.html">transaction callbacks</a>, and <a href="https://api.rubyonrails.org/classes/ActiveRecord/Locking/Pessimistic.html">pessimistic locking</a>.</p>
    HTML
  },
  {
    author: "Bien", legacy_title: "Docker Compose for Rails Development",
    title: "A Repeatable Rails Development Environment with Docker",
    tags: %w[rails docker devops],
    body: <<~HTML
      <h2>Give the application one predictable environment</h2>
      <p>A Rails development stack often includes PostgreSQL, Redis, a web process, and workers. Compose can describe their dependencies and keep service addresses consistent across machines. Inside a container, localhost refers to that container; use the database service's network alias for DATABASE_URL.</p>
      <pre><code class="language-bash">docker compose up --build -d
      docker compose logs -f app
      docker compose exec app bin/rails db:prepare
      docker compose exec app bin/rails test</code></pre>
      <p>These commands assume a Compose service named app and the application's Rails scripts. Database preparation creates or migrates the configured database. For an existing development database, run db:seed explicitly when you want changed demo data applied; preparation is not a promise to rerun seeds on every boot.</p>
      <h2>Separate source files and persistent data</h2>
      <p>Bind-mount application code for quick edits. Use named volumes for database data so recreating a container does not erase it. Avoid deleting volumes as a routine troubleshooting step. Inspect connection settings and logs first.</p>
      <h2>Make startup dependencies real</h2>
      <p>A container starting does not mean its service accepts requests. Add health checks and wait for required services before startup maintenance. Keep a full search reindex out of the normal startup path; a large rebuild can prevent the web server from becoming ready.</p>
      <h2>Keep development behavior explicit</h2>
      <p>Demo accounts and fixed passwords belong to development and test data. Production startup should run migrations with real secrets and should never reset accounts from demo seeds. Document the commands a new teammate needs, then verify them against a fresh development database.</p>
    HTML
  },
  {
    author: "Hung", legacy_title: "RSpec Best Practices for Rails APIs",
    title: "Testing Rails Features Through Their Public Behavior",
    tags: %w[rails testing api],
    body: <<~HTML
      <h2>Choose a behavior worth protecting</h2>
      <p>Useful tests explain what the application promises: an author can create a draft, another author cannot edit it, and readers only see approved posts. Request tests exercise routing, authentication, controller behavior, and database changes together. Model tests are useful for focused validation and state transitions.</p>
      <pre><code class="language-ruby">test "anonymous readers cannot see a draft" do
        post = posts(:draft)
        get post_url(post)
        assert_response :not_found
      end</code></pre>
      <p>This Minitest example requires a draft fixture and a show action whose public visibility policy returns 404 for that record. The expected response should match the application's chosen policy; authenticated owners may have a separate preview route.</p>
      <h2>Assert outcomes, not implementation details</h2>
      <p>When creating a post, assert that one record was saved, its owner is the signed-in user, and its initial state is draft. Submit a forged user_id and verify ownership cannot change. Avoid asserting the exact internal method sequence when a refactor could preserve all user-visible behavior.</p>
      <h2>Control external work</h2>
      <p>Use the test queue adapter to inspect enqueued jobs. Stub provider clients at their application boundary so normal tests do not send email or spend money on AI requests. Keep a separate, explicitly run integration check for provider compatibility.</p>
      <h2>Cover the edges</h2>
      <p>Include blank input, unauthorized access, withdrawn publication, and transient service failures. Use time helpers when testing expiry, and avoid random fixture dates. A small deterministic suite that catches permission leaks and broken workflows is more valuable than many assertions that merely repeat the implementation.</p>
    HTML
  },
  {
    author: "Nhat", legacy_title: "JWT Authentication in Rails APIs",
    title: "Authorization in Rails: Protecting Every Post Action",
    tags: %w[rails security api],
    body: <<~HTML
      <h2>Authentication is only the first check</h2>
      <p>Knowing who signed in does not establish which records they may change. A blog needs separate rules for reading, editing, publishing, and moderation. Write these rules down before implementing controllers so each route enforces the same policy.</p>
      <pre><code class="language-ruby">before_action :authenticate_user!, only: [:edit, :update]

      def update
        @post = current_user.posts.find(params[:id])
        if @post.update(post_params)
          redirect_to @post, status: :see_other
        else
          render :edit, status: :unprocessable_entity
        end
      end</code></pre>
      <p>Scoping through current_user.posts blocks access to another author's record. If verified posts are locked for editing, add that state check before updating. Keep privileged fields such as role, verified, and user_id out of author strong parameters.</p>
      <h2>Match the authentication mechanism to the client</h2>
      <p>For a browser Rails application, session cookies work with the framework's request protections. Preserve CSRF protection for cookie-authenticated state changes. Token authentication for a separate API has different requirements, including token expiry and revocation; adding a token does not remove the need for authorization.</p>
      <h2>Check every entry point</h2>
      <p>The same rule must apply to HTML, JSON, background actions, and AI tools. A disabled edit button is helpful interface feedback, but the server still needs to reject a crafted request. Public lists, search, and downloads must respect the visibility policy too.</p>
      <h2>Test with two authors</h2>
      <p>Verify that each author can change their own permitted draft and cannot change the other author's record. Add a request that submits privileged parameters. Confirm the operation fails without changing ownership or approval state.</p>
      <p>Reference: <a href="https://guides.rubyonrails.org/security.html">Securing Rails Applications</a>.</p>
    HTML
  },
  {
    author: "Tienbob",
    title: "Building a Bounded AI Agent for a Rails Blog",
    tags: %w[rails ruby ai agents architecture],
    body: <<~HTML
      <h2>Give the agent a small job</h2>
      <p>Start with an assistant that finds approved Rails articles and prepares a reading summary. An agent differs from a single text completion because it can request tools and use their results in another model step. Keep that loop bounded and make tool permissions application code, not a promise in the prompt.</p>
      <h2>Expose a narrow read-only tool</h2>
      <pre><code class="language-ruby">class FindPublishedPosts
        def call(query:)
          term = query.to_s.strip.first(120)
          return [] if term.empty?

          Post.where(status: :published, verified: true)
            .where("title ILIKE ?", "%" + Post.sanitize_sql_like(term) + "%")
            .limit(5).pluck(:id, :title)
            .map { |id, title| { id: id, title: title } }
        end
      end</code></pre>
      <p>This intentionally simple tool returns only IDs and titles. Register it through your provider adapter using a schema with a required string query. The adapter must validate the model's arguments, dispatch only registered tool names, and return the tool result with the matching call ID. Do not let the model choose arbitrary Ruby methods or SQL.</p>
      <h2>Control the loop</h2>
      <p>Allow at most three model turns and five total tool calls, with request timeouts and a token budget. If the model requests more work, return a useful partial answer. Run provider calls in a background job and store the run status so the browser can show progress without holding a web request open.</p>
      <h2>Separate suggestions from actions</h2>
      <p>Retrieved article text may contain instructions; treat it as untrusted content. Authorize each tool using the current actor. If publishing tools are added later, require a separate authorized confirmation and an idempotency key before performing the write. Never publish merely because the model asks.</p>
      <h2>Evaluate the agent</h2>
      <p>Test unknown tools, malformed arguments, private post requests, timeouts, and repeated calls. Record tool names, durations, and costs without logging secrets. A successful reading assistant cites real post IDs and reports missing evidence instead of inventing an article.</p>
    HTML
  },
  {
    author: "Quy",
    title: "Simple RAG in Rails: Answer Questions from Your Blog",
    tags: %w[rails ruby ai rag postgresql],
    body: <<~HTML
      <h2>Retrieve first, then generate</h2>
      <p>Retrieval-augmented generation gives a model relevant source text before it answers. For a Rails blog, start with approved articles and return citations to the original posts. The model is not a replacement for the database: Rails decides which content is visible and which passages are sent.</p>
      <h2>Build a small indexing pipeline</h2>
      <p>Extract plain text from Action Text, split it into passages of a few hundred words, and store each passage with its post ID and content digest. Generate embeddings with one chosen model, then store the vectors in PostgreSQL with pgvector. The vector column's dimensions must match that model's output. Use a background job, and remove or replace old passages when a post changes.</p>
      <h2>Keep retrieval behind one interface</h2>
      <pre><code class="language-ruby">class BlogAnswer
        def initialize(retriever:, generator:)
          @retriever = retriever
          @generator = generator
        end

        def call(question:)
          passages = @retriever.call(question: question, limit: 4)
          return { answer: "No relevant approved article found.", sources: [] } if passages.empty?

          {
            answer: @generator.call(question: question, passages: passages),
            sources: passages.map { |p| p.fetch(:post_id) }.uniq
          }
        end
      end</code></pre>
      <p>The retriever and generator are application adapters, not built-in Rails APIs. The retriever embeds the question with the same embedding model, searches by vector distance, and joins the current posts table to require published and verified records. Apply a relevance cutoff calibrated against your own questions; nearest does not necessarily mean relevant.</p>
      <h2>Make the answer verifiable</h2>
      <p>Pass labeled excerpts to the generator with instructions to use only those excerpts and to admit missing evidence. Treat excerpts as data rather than commands. Render source links from the IDs Rails returned, and reject any generated citation outside that set. Escape model text before displaying it.</p>
      <h2>Check the failure cases</h2>
      <p>Try a question answered by one article, a question with no evidence, and a post withdrawn after indexing. Measure retrieval accuracy before tuning prose. Bound passage count and provider timeouts, avoid sending private drafts, and reindex all passages when changing embedding models.</p>
    HTML
  },
  {
    author: "Bien",
    title: "Managing a Rails Project: A PM's Guide to Scope and Delivery",
    tags: %w[rails management project-management delivery],
    body: <<~HTML
      <h2>Start with the outcome</h2>
      <p>As PM, I want the team to agree on the problem before estimating the solution. For a Rails blog, a useful outcome is that an author can submit an article and an administrator can approve it without losing either person's work. Write that journey in plain language and identify how we will know it works.</p>
      <h2>Turn scope into observable acceptance criteria</h2>
      <p>For a moderation feature, define who may submit, who may approve, what readers can see, and what happens after rejection. Include unhappy paths: a reviewer opens a stale version, an email fails, or a search update is delayed. A story is ready for delivery when design, engineering, and stakeholders share the same answers.</p>
      <h2>Deliver a small complete slice</h2>
      <p>Our first slice might cover saving a draft, submitting it, reviewing it, and showing an approved article. Defer AI review and advanced search until that basic flow is usable. Split work by demonstrable behavior rather than separate weeks of database, backend, and frontend work that cannot be reviewed together.</p>
      <h2>Make dependencies and tradeoffs visible</h2>
      <p>Keep a short risk register with an owner and next action for each risk. If search requires infrastructure or email requires credentials, surface that dependency before the feature reaches acceptance. Ask engineers to explain uncertainty, then plan a small investigation rather than treating an uncertain estimate as a commitment.</p>
      <p>When a new requirement arrives, show its effect on scope and timing. Offer concrete choices: keep the release date and defer an optional feature, or add the feature and revise the forecast. Record the decision so the team does not repeatedly reopen it.</p>
      <h2>Use a predictable delivery rhythm</h2>
      <p>Review blocked work frequently, demonstrate completed journeys each week, and keep one shared view of the release scope. A status update should state what is usable, what is at risk, and what decision is needed. Avoid measuring progress only by tickets closed when the customer still cannot complete the workflow.</p>
      <h2>Prepare the release and learn from it</h2>
      <p>Before release, agree on migration ownership, smoke checks, rollback criteria, and support contacts. For this blog, verify author access, approval visibility, and worker health. After release, inspect completion rates and support feedback, then turn the largest friction into the next small improvement. The PM's responsibility is to make delivery decisions clear and keep the team connected to the outcome.</p>
    HTML
  },
  {
    author: "Manh",
    title: "Leading a Rails Division: Technical Direction and Team Ownership",
    tags: %w[rails management leadership architecture],
    body: <<~HTML
      <h2>Set direction that teams can use</h2>
      <p>As division lead, my job is to help several teams make compatible decisions without requiring my approval for every change. Define a few engineering expectations: enforce authorization on the server, ship reversible changes, observe production behavior, and give every service a clear owner. Connect each expectation to a real failure it prevents.</p>
      <h2>Assign ownership beyond implementation</h2>
      <p>A feature owner should know its user journey, operational risks, dashboards, and recovery steps. For a Rails publication system, identify who owns moderation, search freshness, and background processing. Boundaries should make incident response easier, rather than create gaps where every team assumes another team is responsible.</p>
      <h2>Review consequential decisions</h2>
      <p>Use short architecture decision records for choices that affect several teams, data durability, or long-term cost. Document the problem, alternatives, chosen approach, and conditions that would make us revisit it. A search indexing design should state the tolerated delay and repair strategy, not simply name a queue library.</p>
      <p>Delegate routine implementation choices to the team closest to the work. Escalate decisions with broad consequences, such as a shared authentication change or a new external provider handling private data. Review the decision while alternatives are still affordable.</p>
      <h2>Build capability through real work</h2>
      <p>Pair less experienced engineers with experienced owners on a bounded feature. Ask reviewers to explain tradeoffs and failure scenarios, not merely formatting preferences. Rotate incident participation with support so operational knowledge spreads. Technical depth should become a team capability rather than remain dependent on one senior engineer.</p>
      <h2>Balance delivery and maintenance</h2>
      <p>Reserve visible capacity for upgrades, slow queries, flaky tests, and recovery tooling. Prioritize maintenance by user impact and engineering drag. If repeated indexing incidents delay releases, fixing consistency and observability is delivery work, not an unrelated cleanup exercise.</p>
      <h2>Inspect systems without ranking people by activity</h2>
      <p>Look at review delays, release failures, recurring incidents, and recovery time to locate bottlenecks. Use those signals to improve the process; ticket and commit counts are poor substitutes for contribution. Combine operational evidence with team conversations about workload and unclear ownership.</p>
      <h2>Create a learning loop</h2>
      <p>After an incident, reconstruct what information was available and where defenses failed. Assign a small number of corrective actions with owners, then check completion. Share the lesson across teams when the same Rails pattern appears elsewhere. A division grows stronger when engineers can surface uncertainty early and have the authority and support to resolve it.</p>
    HTML
  }
]
