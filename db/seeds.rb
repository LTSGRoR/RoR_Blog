# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Seeding database..."

# ── Users ───────────────────────────────────────────────────────────────────
seed_password = "password1234"

admin = User.find_or_initialize_by(email: "admin@department.com")
admin.assign_attributes(name: "Admin User", password: seed_password, role: :admin)
admin.skip_confirmation!
admin.save!

authors = [
  { name: "Alice Chen",    email: "alice@department.com" },
  { name: "Bob Marley",    email: "bob@department.com" },
  { name: "Clara Osei",    email: "clara@department.com" },
  { name: "David Kim",     email: "david@department.com" },
  { name: "Eva Rodriguez", email: "eva@department.com" }
].map do |attrs|
  u = User.find_or_initialize_by(email: attrs[:email])
  u.assign_attributes(attrs.merge(password: seed_password, role: :author))
  u.skip_confirmation!
  u.save!
  u
end

all_users = [ admin ] + authors
puts "  #{User.count} users"

# ── Tags ────────────────────────────────────────────────────────────────────
tag_names = %w[rails ruby javascript typescript react hotwire turbo stimulus
               postgresql redis elasticsearch sidekiq docker kubernetes
               devops ci-cd testing rspec performance security api graphql
               architecture patterns refactoring nature photography travel
               productivity career open-source machine-learning]

tags = tag_names.map { |name| Tag.find_or_create_by!(name: name) }
puts "  #{Tag.count} tags"

# ── Posts ───────────────────────────────────────────────────────────────────
posts_data = [
  {
    title: "Getting Started with Hotwire in Rails 8",
    tags: %w[rails hotwire turbo stimulus],
    body: <<~HTML
      <h2>What is Hotwire?</h2>
      <p>Hotwire is an alternative approach to building modern web applications without using much JavaScript by sending HTML instead of JSON over the wire. This makes for fast first-load pages, keeps template rendering on the server, and allows for a dramatically simplified, more productive development experience in any programming language, without sacrificing any of the speed or responsiveness associated with a traditional single-page application.</p>
      <h2>Turbo Drive</h2>
      <p>Turbo Drive accelerates links and form submissions by negating the need for full page reloads. Instead, all clicks on links and form submissions are intercepted and sent as XMLHttpRequests. When the server responds with HTML, Turbo Drive extracts the <code>&lt;body&gt;</code> element from the response, and replaces the current <code>&lt;body&gt;</code> element with the new one.</p>
      <h2>Turbo Frames</h2>
      <p>Turbo Frames allow predefined parts of a page to be updated on request. Any links and forms inside a frame are captured, and the frame contents updated after receiving a response, even for server redirects.</p>
      <pre><code class="language-ruby">class PostsController &lt; ApplicationController
  def create
    @post = Post.new(post_params)
    if @post.save
      redirect_to @post
    else
      render :new, status: :unprocessable_entity
    end
  end
end</code></pre>
      <h2>Stimulus</h2>
      <p>Stimulus is a modest JavaScript framework for the HTML you already have. It pairs beautifully with Turbo to give you a full-stack reactive experience without the complexity of a SPA framework.</p>
    HTML
  },
  {
    title: "Mastering ActiveRecord Performance",
    tags: %w[rails postgresql performance],
    body: <<~HTML
      <h2>The N+1 Query Problem</h2>
      <p>One of the most common performance pitfalls in Rails is the N+1 query problem. This happens when you load a collection of records and then lazily load associated records one by one.</p>
      <pre><code class="language-ruby"># BAD - N+1 queries
posts = Post.all
posts.each { |p| puts p.user.name }

# GOOD - eager loading
posts = Post.includes(:user).all
posts.each { |p| puts p.user.name }</code></pre>
      <h2>Using explain()</h2>
      <p>Rails lets you run <code>EXPLAIN ANALYZE</code> directly from ActiveRecord. This is invaluable for diagnosing slow queries.</p>
      <pre><code class="language-ruby">Post.where(status: :published).explain</code></pre>
      <h2>Counter Caches</h2>
      <p>Use <code>counter_cache: true</code> on associations where you need to display counts without a full COUNT(*) query every time.</p>
      <h2>Database Indexes</h2>
      <p>Always index foreign keys, frequently queried columns, and columns used in ORDER BY clauses. Missing indexes are often the #1 cause of slow production queries.</p>
    HTML
  },
  {
    title: "Sidekiq: Background Jobs Done Right",
    tags: %w[rails sidekiq redis],
    body: <<~HTML
      <h2>Why Background Jobs?</h2>
      <p>Any operation that isn't strictly needed for the HTTP response should be moved to a background job: sending emails, calling external APIs, image processing, generating reports. Keeping these out of the request cycle keeps your app fast and resilient.</p>
      <h2>Setting Up Sidekiq</h2>
      <pre><code class="language-ruby"># Gemfile
gem "sidekiq"

# config/application.rb
config.active_job.queue_adapter = :sidekiq</code></pre>
      <h2>Writing a Job</h2>
      <pre><code class="language-ruby">class SendWelcomeEmailJob &lt; ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    UserMailer.welcome(user).deliver_now
  end
end</code></pre>
      <h2>Retries and Error Handling</h2>
      <p>Sidekiq automatically retries failed jobs with exponential backoff. You can customize retry count and specific error handling using <code>sidekiq_options</code> and <code>rescue_from</code>.</p>
    HTML
  },
  {
    title: "Elasticsearch with Searchkick: Full-Text Search in Rails",
    tags: %w[rails elasticsearch],
    body: <<~HTML
      <h2>Why Searchkick?</h2>
      <p>Searchkick provides a clean Ruby API over Elasticsearch, handling index management, query construction, and result pagination. It integrates natively with ActiveRecord and supports boosting, autocomplete, and more.</p>
      <h2>Basic Setup</h2>
      <pre><code class="language-ruby">class Post &lt; ApplicationRecord
  searchkick word_middle: [:title, :tags]

  def search_data
    {
      title: title,
      body: body.to_plain_text,
      tags: tags.map(&:name)
    }
  end
end</code></pre>
      <h2>Searching</h2>
      <pre><code class="language-ruby">Post.search("rails performance", fields: ["title^5", "tags^3", "body"])</code></pre>
      <h2>Keeping the Index Fresh</h2>
      <p>Use <code>callbacks: :async</code> so index updates are processed by Sidekiq, not inline in your request. Use <code>touch: true</code> on join-table <code>belongs_to</code> associations so tag changes propagate to the index automatically.</p>
    HTML
  },
  {
    title: "Docker Compose for Rails Development",
    tags: %w[rails docker devops],
    body: <<~HTML
      <h2>Why Docker for Development?</h2>
      <p>Docker Compose lets every developer on the team run the exact same stack — PostgreSQL, Redis, Elasticsearch — without installing anything locally. It eliminates "works on my machine" forever.</p>
      <h2>A Minimal docker-compose.yml</h2>
      <pre><code class="language-yaml">services:
  db:
    image: postgres:16
    environment:
      POSTGRES_PASSWORD: password
  redis:
    image: redis:7-alpine
  web:
    build: .
    command: bin/rails server -b 0.0.0.0
    volumes:
      - .:/app
    ports:
      - "3000:3000"
    depends_on: [db, redis]</code></pre>
      <h2>Tips</h2>
      <p>Mount your source code as a volume so code changes are reflected immediately. Use named volumes for database data so it persists between container restarts.</p>
    HTML
  },
  {
    title: "RSpec Best Practices for Rails APIs",
    tags: %w[rails rspec testing api],
    body: <<~HTML
      <h2>Request Specs Over Controller Specs</h2>
      <p>Use request specs (<code>spec/requests/</code>) to test your API endpoints end-to-end through the full Rails stack. They're faster to write and test what actually matters.</p>
      <h2>Factories with FactoryBot</h2>
      <pre><code class="language-ruby">FactoryBot.define do
  factory :post do
    title { Faker::Lorem.sentence }
    association :user
    status { :published }
  end
end</code></pre>
      <h2>Shared Examples</h2>
      <p>Use <code>shared_examples_for</code> to DRY up common behaviour across multiple specs, such as authentication requirements.</p>
      <h2>VCR for External HTTP</h2>
      <p>Record and replay external HTTP interactions with the VCR gem so your tests are fast and deterministic without hitting real APIs.</p>
    HTML
  },
  {
    title: "JWT Authentication in Rails APIs",
    tags: %w[rails api security],
    body: <<~HTML
      <h2>Stateless Auth</h2>
      <p>JWTs let you build stateless APIs — the server doesn't store session state. Each request carries its own credentials in the Authorization header.</p>
      <h2>Generating Tokens</h2>
      <pre><code class="language-ruby">payload = { user_id: user.id, exp: 24.hours.from_now.to_i }
token = JWT.encode(payload, Rails.application.secret_key_base, "HS256")</code></pre>
      <h2>Verifying Tokens</h2>
      <pre><code class="language-ruby">decoded = JWT.decode(token, Rails.application.secret_key_base, true, algorithm: "HS256")
user_id = decoded.first["user_id"]</code></pre>
      <h2>Security Considerations</h2>
      <p>Always set an expiry. Use HTTPS. Store the secret key outside of source control. Consider refresh tokens for long-lived sessions.</p>
    HTML
  },
  {
    title: "GraphQL in Rails with graphql-ruby",
    tags: %w[rails graphql api],
    body: <<~HTML
      <h2>Why GraphQL?</h2>
      <p>GraphQL lets clients request exactly the data they need, reducing over-fetching and under-fetching. It's especially powerful for complex UIs that consume diverse data.</p>
      <h2>Defining a Type</h2>
      <pre><code class="language-ruby">class Types::PostType &lt; Types::BaseObject
  field :id, ID, null: false
  field :title, String, null: false
  field :tags, [Types::TagType], null: false
end</code></pre>
      <h2>Mutations</h2>
      <p>Mutations in graphql-ruby are first-class citizens — they validate input, call your service objects, and return structured results including errors.</p>
      <h2>N+1 with dataloader</h2>
      <p>Use <code>dataloader</code> (built into graphql-ruby 2.x) to batch-load associations and avoid N+1 queries in resolvers.</p>
    HTML
  },
  {
    title: "TypeScript for Rails Developers",
    tags: %w[typescript javascript],
    body: <<~HTML
      <h2>Why TypeScript?</h2>
      <p>TypeScript brings static types to JavaScript, catching whole classes of bugs at compile time. For Rails developers used to the comfort of Ruby's expressiveness, TypeScript offers a similar "guardrails" experience on the frontend.</p>
      <h2>Type Inference</h2>
      <p>You don't need to annotate everything. TypeScript infers types wherever it can — let it do the work.</p>
      <pre><code class="language-typescript">const greet = (name: string) => `Hello, ${name}`
const result = greet("Alice") // inferred as string</code></pre>
      <h2>Interfaces vs Types</h2>
      <p>Use <code>interface</code> for object shapes you expect to extend; use <code>type</code> for unions, intersections, and aliases.</p>
      <h2>Using with Stimulus</h2>
      <p>Stimulus works great with TypeScript. Add <code>@hotwired/stimulus</code> types and annotate your controller methods for a much better IDE experience.</p>
    HTML
  },
  {
    title: "Clean Architecture Patterns in Ruby",
    tags: %w[ruby architecture patterns refactoring],
    body: <<~HTML
      <h2>Fat Models, Skinny Controllers — Then What?</h2>
      <p>The classic Rails advice to put logic in models works to a point, but complex domains need more structure. Service objects, form objects, and query objects let you keep each class focused on a single responsibility.</p>
      <h2>Service Objects</h2>
      <pre><code class="language-ruby">class PublishPost
  def initialize(post, publisher)
    @post = post
    @publisher = publisher
  end

  def call
    return false unless @publisher.can_publish?
    @post.update!(status: :published, published_at: Time.current)
    NotifySubscribersJob.perform_later(@post)
    true
  end
end</code></pre>
      <h2>Query Objects</h2>
      <p>Extract complex ActiveRecord queries into dedicated query objects. This keeps them testable in isolation and keeps your models and controllers clean.</p>
    HTML
  },
  {
    title: "Kubernetes for the Rails Developer",
    tags: %w[kubernetes docker devops],
    body: <<~HTML
      <h2>Pods, Deployments, Services</h2>
      <p>Kubernetes organizes your app around Pods (the smallest deployable unit), Deployments (desired state declaratively described), and Services (stable network endpoints).</p>
      <h2>A Rails Deployment Manifest</h2>
      <pre><code class="language-yaml">apiVersion: apps/v1
kind: Deployment
metadata:
  name: rails-web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: rails-web
  template:
    spec:
      containers:
        - name: rails
          image: myrepo/my-rails-app:latest
          env:
            - name: RAILS_ENV
              value: production</code></pre>
      <h2>Zero-Downtime Deploys</h2>
      <p>Use rolling updates and readiness probes so Kubernetes never routes traffic to a pod that isn't ready.</p>
    HTML
  },
  {
    title: "CI/CD Pipelines with GitHub Actions",
    tags: %w[ci-cd rails testing],
    body: <<~HTML
      <h2>Why Automate?</h2>
      <p>A good CI pipeline catches bugs before they reach production, enforces code style, and gives the team confidence to deploy frequently.</p>
      <h2>A Minimal Rails Workflow</h2>
      <pre><code class="language-yaml">name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: postgres
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - run: bin/rails db:schema:load
      - run: bin/rails test</code></pre>
      <h2>Caching Dependencies</h2>
      <p>Use <code>bundler-cache: true</code> with the <code>ruby/setup-ruby</code> action to cache your bundle between runs. This alone can cut CI time in half.</p>
    HTML
  },
  {
    title: "Nature Photography Tips I Learned the Hard Way",
    tags: %w[nature photography],
    body: <<~HTML
      <h2>Golden Hour is Non-Negotiable</h2>
      <p>The hour after sunrise and the hour before sunset produce light that no filter can replicate. Wake up early, stay out late.</p>
      <h2>Patience Over Perfect Gear</h2>
      <p>You do not need a $5000 telephoto lens to take compelling nature shots. What you need is patience, knowledge of your subject's behaviour, and willingness to sit very still for a long time.</p>
      <h2>Learn to Read the Weather</h2>
      <p>Stormy skies produce dramatic images. Overcast days diffuse light beautifully for macro work. No weather is "bad" — only unprepared photographers are.</p>
    HTML
  },
  {
    title: "Lessons from Two Years of Remote Work",
    tags: %w[productivity career],
    body: <<~HTML
      <h2>Routine is Freedom</h2>
      <p>Without the structure of commuting and office hours, you must create your own. A consistent morning routine — same wake time, same start time — is the single biggest factor in remote productivity.</p>
      <h2>Over-Communicate in Writing</h2>
      <p>Remote teams succeed or fail on written communication. Write down decisions, context, and reasoning. Future you (and your teammates) will be grateful.</p>
      <h2>Guard Your Deep Work</h2>
      <p>Block out large chunks of uninterrupted time for complex work. Notifications are productivity poison. Use async communication by default.</p>
    HTML
  },
  {
    title: "Intro to Machine Learning with Ruby",
    tags: %w[ruby machine-learning],
    body: <<~HTML
      <h2>Ruby for ML?</h2>
      <p>Ruby isn't Python, but the ecosystem has grown. Libraries like <code>rumale</code> (scikit-learn-inspired) and <code>torch.rb</code> (PyTorch bindings) make real ML work viable.</p>
      <h2>A Simple Classifier</h2>
      <pre><code class="language-ruby">require "rumale"

x = Rumale::Dataset.load_libsvm_file("data.svm").first
y = Rumale::Dataset.load_libsvm_file("data.svm").last

svc = Rumale::LinearModel::SVC.new
svc.fit(x, y)
predictions = svc.predict(x)</code></pre>
      <h2>When to Use Python Instead</h2>
      <p>For serious ML work — training large models, GPU acceleration, the full PyTorch/TensorFlow ecosystem — Python is the better choice. Use Ruby to serve predictions via an API, not to train models.</p>
    HTML
  }
]

posts_data.each_with_index do |data, i|
  user = all_users[i % all_users.length]
  post = Post.find_or_initialize_by(title: data[:title])

  unless post.persisted?
    post.user   = user
    post.status = :published
    post.verified = true
    post.verified_at = rand(1..90).days.ago
    post.verified_by_id = admin.id
    post.created_at = rand(1..180).days.ago
    post.body = data[:body]
    post.save!

    tag_records = data[:tags].map { |name| Tag.find_or_create_by!(name: name) }
    post.tags = tag_records
  end
end

puts "  #{Post.count} posts"
puts "Done! ✓"
