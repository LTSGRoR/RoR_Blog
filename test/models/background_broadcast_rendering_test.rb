ENV["RAILS_ENV"] ||= "test"
ENV["EMBEDDINGS_AUTO_RUN_ON_BOOT"] = "false"
require_relative "../../config/environment"
require "active_support/test_case"
require "minitest/autorun"
require "minitest/mock"

# Use the real renderer and templates, but avoid database/session dependencies.
class BackgroundBroadcastRenderingTest < ActiveSupport::TestCase
  test "all moderation broadcast partials render across states and locales without Warden" do
    partials = %w[posts/ai_review_panel posts/mine_visibility_cell posts/mine_updated_cell
      admin/posts/post_status_cell admin/posts/post_ai_review_cell
      admin/posts/post_submitted_cell admin/posts/post_ai_assessment_section]
    I18n.available_locales.each do |locale|
      I18n.with_locale(locale) do
        %w[pending in_progress failed needs_admin_review auto_approved].each do |state|
          post = record(Post, to_key: [ 9 ], to_param: "9", updated_at: Time.current,
            ai_review_status: state, ai_review_in_progress?: state == "in_progress",
            ai_review_pending?: state == "pending", ai_review_failed?: state == "failed",
            published?: true, draft?: false, verified?: state == "auto_approved",
            unverify_reason: nil, ai_last_error: state == "failed" ? "Provider unavailable" : nil,
            ai_decision_payload: { "reason" => "Review reason" }, ai_confidence: 0.9,
            ai_risk_score: 0.1, ai_model_name: "model", ai_provider: "provider", ai_reviewed_at: Time.current)
          partials.each do |partial|
            assert_match(/<(div|td)/, ApplicationController.render(partial: partial, locals: { post: post }))
          end
        end
      end
    end
  end

  test "post actions with back button render without a session" do
    post = record(Post, to_param: "9")
    html = ApplicationController.render(partial: "posts/post_actions", locals: { post: post, show_back: true })
    assert_includes html, "/en/posts"
  end

  test "user rows and summary render all account states without a session" do
    I18n.available_locales.each do |locale|
      I18n.with_locale(locale) do
        %i[active banned suspended admin].each do |state|
          user = record(User, id: 7, to_param: "7", name: "Example", email: "user@example.com",
            role: state == :admin ? "admin" : "user", admin?: state == :admin,
            banned?: state == :banned, suspended?: state == :suspended,
            suspended_until: 1.day.from_now, suspended_time_zone: "UTC")
          assert_includes ApplicationController.render(partial: "users/user_row", locals: { user: user, i: 0 }), "user_7"
        end
        assert_includes ApplicationController.render(partial: "users/users_summary", locals: {
          total_count: 4, active_count: 2, suspended_count: 1, banned_count: 1
        }), "users_summary"
      end
    end
  end

  test "chat rendering handles pending and completed responses without a session" do
    [ nil, "An answer" ].each do |response|
      chat = record(ChatHistory, to_key: [ 4 ], user_message: "A question", bot_response: response)
      chat.define_singleton_method(:suggested_posts) { |**| [] }
      assert_includes ApplicationController.render(partial: "chat_histories/chat_history_item", locals: { chat_history: chat }), "chat_history_4"
    end
  end

  test "suggestion thumbnail renders a lazy URL without processing its variant" do
    blob = record(ActiveStorage::Blob, signed_id: "test-blob", filename: ActiveStorage::Filename.new("thumbnail.png"))
    variant = ActiveStorage::Variant.new(blob, resize_to_fill: [ 96, 96 ])
    variant.define_singleton_method(:processed) { raise "Must not process images in a broadcast" }
    thumbnail = Object.new
    thumbnail.define_singleton_method(:attached?) { true }
    thumbnail.define_singleton_method(:variant) { |**| variant }
    body = Struct.new(:to_plain_text).new("Post content")
    user = record(User, name: "Author", email: "author@example.com")
    post = record(Post, to_param: "9", title: "Example post", thumbnail: thumbnail, body: body, user: user)
    html = ApplicationController.render(partial: "chat_histories/suggested_post_card", locals: { post: post })
    assert_includes html, "/rails/active_storage/representations/"
  end

  test "Sidekiq forwards errors without including private job arguments" do
    config = Struct.new(:redis, :error_handlers).new(nil, [])
    configure = ->(&block) { block.call(config) }
    Sidekiq.stub(:configure_server, configure) do
      Sidekiq::Cron::Job.stub(:load_from_hash, nil) do
        # Evaluate the server block even though this test runs outside Sidekiq.
        load Rails.root.join("config/initializers/sidekiq.rb")
      end
    end
    error = RuntimeError.new("Broadcast failed")
    reports = []
    Rails.error.stub(:report, ->(*args, **options) { reports << [ args, options ] }) do
      config.error_handlers.last.call(error, { job: {
        "wrapped" => "Turbo::Streams::ActionBroadcastJob", "jid" => "job-1",
        "queue" => "default", "args" => [ "private message" ]
      } }, config)
    end
    assert_equal [ error ], reports.first.first
    assert_equal false, reports.first.last[:handled]
    assert_equal "sidekiq", reports.first.last[:source]
    assert_equal({ job_class: "Turbo::Streams::ActionBroadcastJob", job_id: "job-1", queue: "default" }, reports.first.last[:context])
  end

  private

  def record(klass, **attributes)
    klass.allocate.tap do |instance|
      attributes.each { |name, value| instance.define_singleton_method(name) { |*| value } }
    end
  end
end
