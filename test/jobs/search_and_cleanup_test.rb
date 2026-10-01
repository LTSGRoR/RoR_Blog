require "test_helper"

class SearchAndCleanupTest < ActiveSupport::TestCase
  test "destroy queues search cleanup and missing records delete the index document" do
    post = create_post(user: create_user)
    id = post.id
    assert_enqueued_with(job: PostSearchIndexJob, args: [ id ]) { post.destroy! }
    removed = nil
    index = Object.new
    index.define_singleton_method(:remove) { |record| removed = record.id }
    Post.stub(:search_index, index) { PostSearchIndexJob.perform_now(id) }
    assert_equal id, removed
  end

  test "extending suspension after cleanup reads IDs preserves new expiry" do
    user = create_user
    user.update!(suspended_until: 1.minute.ago)
    scope = User.where(suspended_until: ..Time.current)
    original = User.method(:where)
    scope.define_singleton_method(:pluck) do |*_args|
      user.update!(suspended_until: 1.day.from_now)
      [ user.id ]
    end
    replacement = lambda do |*args|
      args.first.key?(:id) ? original.call(*args) : scope
    end
    User.stub(:where, replacement) { ClearExpiredSuspensionsJob.perform_now }
    assert user.reload.suspended?
  end

  test "expired chats never consume provider requests" do
    chat = ChatHistory.create!(user: create_user, user_message: "Old request", created_at: 11.minutes.ago)
    AiGeneration::Service.stub(:new, -> { flunk "Provider should not be called" }) do
      GeneratePostSuggestionJob.perform_now(chat.id)
    end
    assert chat.reload.bot_response.present?
  end

  test "deleting a post removes it from real search results" do
    old_suffix = Searchkick.index_suffix
    Searchkick.index_suffix = "audit_delete_#{Process.pid}"
    index = Post.search_index
    index.create
    post = create_post(user: create_user, verified: true)
    PostSearchIndexJob.perform_now(post.id)
    index.refresh
    assert_equal 1, Post.search("*", where: { id: post.id }, load: false).total_count
    id = post.id
    post.destroy!
    PostSearchIndexJob.perform_now(id)
    index.refresh
    assert_equal 0, Post.search("*", where: { id: id }, load: false).total_count
  ensure
    index&.delete
    Searchkick.index_suffix = old_suffix
  end
end
