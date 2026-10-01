require "test_helper"

class RevisionAndLimitsTest < ActiveSupport::TestCase
  setup do
    @author = create_user
    @admin = create_user(role: :admin)
    @post = create_post(user: @author, verified: true)
  end

  test "only pending revisions can be approved or rejected" do
    %i[draft approved rejected].each do |state|
      revision = create_revision(post: @post, state: state)
      assert_raises(ArgumentError) { revision.approve!(admin: @admin) }
      assert_raises(ArgumentError) { revision.reject!(admin: @admin, note: "Rejected") }
    end
    assert_equal "Original title", @post.reload.title
  end

  test "replaying an approval cannot overwrite a later post version" do
    revision = create_revision(post: @post)
    revision.approve!(admin: @admin)
    @post.reload.update!(title: "Later version")
    assert_raises(ArgumentError) { revision.approve!(admin: @admin) }
    assert_equal "Later version", @post.reload.title
  end

  test "chat enforces pending and input limits" do
    ChatHistory::USER_PENDING_LIMIT.times do
      ChatHistory.accept_request!(user: @author, post: nil, message: "A question")
    end
    assert_raises(ChatHistory::QuotaExceeded) do
      ChatHistory.accept_request!(user: @author, post: nil, message: "Another question")
    end
    chat = ChatHistory.new(user: @author, user_message: "x" * (ChatHistory::MAX_MESSAGE_LENGTH + 1))
    assert_not chat.valid?
    assert chat.errors[:user_message].any?
  end

  test "chat daily quota includes failed requests from every user" do
    ChatHistory.where(created_at: Time.current.beginning_of_day..).delete_all
    ChatHistory::DAILY_LIMIT.times do |i|
      ChatHistory.create!(user: @admin, user_message: "Question #{i}", bot_response: "Failed")
    end
    assert_raises(ChatHistory::QuotaExceeded) do
      ChatHistory.accept_request!(user: @author, post: nil, message: "Over daily budget")
    end
  end

  test "unsupported avatar uploads are rejected" do
    @author.avatar.attach(io: StringIO.new("<html>bad</html>"), filename: "avatar.html", content_type: "text/html", identify: false)
    assert_not @author.valid?
    assert @author.errors[:avatar].any?
  end

  test "oversized avatar uploads are rejected" do
    @author.avatar.attach(io: StringIO.new("x" * 3.megabytes), filename: "large.png", content_type: "image/png", identify: false)
    assert_not @author.valid?
    assert @author.errors[:avatar].any?
  end

  test "a legacy unsupported upload does not prevent suspension" do
    blob = ActiveStorage::Blob.create!(key: SecureRandom.uuid, filename: "old.html", content_type: "text/html", byte_size: 1, checksum: "test", service_name: "test", metadata: { identified: true })
    ActiveStorage::Attachment.create!(record: @author, name: "avatar", blob: blob)
    assert @author.reload.update(suspended_until: 1.day.from_now)
  end

  test "post and revision thumbnails must be images" do
    [ @post, create_revision(post: @post, state: :draft) ].each do |record|
      record.thumbnail.attach(io: StringIO.new("<html>bad</html>"), filename: "image.html", content_type: "text/html", identify: false)
      assert_not record.valid?
      assert record.errors[:thumbnail].any?
    end
  end

  test "hourly chat quota includes completed requests" do
    ChatHistory::USER_HOURLY_LIMIT.times do
      ChatHistory.create!(user: @author, user_message: "Question", bot_response: "Completed")
    end
    assert_raises(ChatHistory::QuotaExceeded) do
      ChatHistory.accept_request!(user: @author, post: nil, message: "Over hourly budget")
    end
  end

  test "comment body size is bounded" do
    comment = Comment.new(post: @post, user: @author, body: "x" * 5_001)
    assert_not comment.valid?
  end
end
