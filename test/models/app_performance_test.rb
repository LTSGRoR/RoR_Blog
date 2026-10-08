ENV["RAILS_ENV"] ||= "test"
ENV["EMBEDDINGS_AUTO_RUN_ON_BOOT"] = "false"
require_relative "../../config/environment"
require "active_support/test_case"
require "minitest/autorun"
require "minitest/mock"

class AppPerformanceTest < ActiveSupport::TestCase
  test "bootstrap queues bounded ID batches and returns the total" do
    scope = Object.new
    scope.define_singleton_method(:in_batches) do |of:, &block|
      raise "Incorrect batch bound" unless of == 500
      [ [ 1, 2 ], [ 3 ] ].each do |ids|
        batch = Object.new
        batch.define_singleton_method(:pluck) { |_| ids }
        block.call(batch)
      end
    end
    queued = []
    Post.stub(:where, scope) do
      IndexPostEmbeddingsJob.stub(:perform_later, ->(id) { queued << id }) do
        assert_equal 3, Embeddings::Bootstrap.enqueue_missing_verified_posts!(logger: Logger.new(File::NULL))
      end
    end
    assert_equal [ 1, 2, 3 ], queued
  end

  test "unchanged embedding releases its session lock without opening a transaction" do
    run_embedding(provider_failure: false, unchanged: true)
  end

  test "provider failure releases the session lock before propagating" do
    run_embedding(provider_failure: true, unchanged: false)
  end

  private

  def run_embedding(provider_failure:, unchanged:)
    post = Object.new
    post.define_singleton_method(:id) { 7 }
    post.define_singleton_method(:reload) { self }
    post.define_singleton_method(:embedding) { unchanged ? [ 0.1 ] : nil }
    post.define_singleton_method(:embedding_source_digest) { Digest::SHA256.hexdigest("source") }
    statements = []
    connection = Object.new
    connection.define_singleton_method(:select_value) { |sql| statements << sql; true }
    pool = Object.new
    pool.define_singleton_method(:with_connection) { |&block| block.call(connection) }
    service = Object.new
    service.define_singleton_method(:embed) { |**| raise "Provider unavailable" }
    job = IndexPostEmbeddingsJob.new
    job.define_singleton_method(:embedding_source_text) { |_| "source" }
    Post.stub(:find_by, post) do
      Post.stub(:connection_pool, pool) do
        Post.stub(:transaction, ->(*) { flunk "Provider must not run inside a transaction" }) do
          AiGeneration::Service.stub(:new, service) do
            if provider_failure
              assert_raises(RuntimeError) { job.perform(7) }
            else
              job.perform(7)
            end
          end
        end
      end
    end
    assert_equal [ "SELECT pg_try_advisory_lock(741902003, 7)", "SELECT pg_advisory_unlock(741902003, 7)" ], statements
  end
end
