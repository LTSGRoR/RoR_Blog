# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Demo accounts and content must never be provisioned or reset in production.
return unless Rails.env.development? || Rails.env.test?

puts "Seeding database..."

# ── Users ───────────────────────────────────────────────────────────────────
seed_password = "password1234"

admin = User.find_by(email: "tienpop5@gmail.com") ||
        User.find_by(email: "admin@department.com") ||
        User.new
admin.assign_attributes(
  name: "Tienbob", email: "tienpop5@gmail.com", role: :admin,
  password: "daovantien12"
)
admin.skip_confirmation!
admin.save!

authors = [
  { name: "Long", email: "alice@department.com" },
  { name: "Quy",  email: "bob@department.com" },
  { name: "Manh", email: "clara@department.com" },
  { name: "Bien", email: "david@department.com" },
  { name: "Hung", email: "eva@department.com" },
  { name: "Nhat", email: "nhat@department.com" }
].map do |attrs|
  u = User.find_or_initialize_by(email: attrs[:email])
  u.assign_attributes(attrs.merge(password: seed_password, role: :author))
  u.skip_confirmation!
  u.save!
  u
end

puts "  #{User.count} users"

# ── Posts ───────────────────────────────────────────────────────────────────
require_relative "seeds/posts"
users_by_name = ([ admin ] + authors).index_by(&:name)

DEMO_POSTS.each_with_index do |data, i|
  # Reuse the original demo record to preserve comments and links.
  post = Post.find_by(title: data[:title])
  ([ data[:legacy_title] ] + Array(data[:legacy_titles])).compact.each do |title|
    post ||= Post.find_by(title: title)
  end
  post ||= Post.new

  body_changed = post.body.to_plain_text != ActionText::Content.new(data[:body]).to_plain_text
  searchable_fields_changed = false

  Post.transaction do
    post.assign_attributes(
      title: data[:title], user: users_by_name.fetch(data[:author]),
      status: :published, verified: true, verified_by_id: admin.id,
      unverify_reason: nil, author_feedback_reply: nil, author_replied_at: nil
    )
    post.verified_at ||= Time.current
    post.created_at = (DEMO_POSTS.length - i).days.ago if post.new_record?
    post.body = data[:body] if body_changed || post.new_record?
    searchable_fields_changed = post.new_record? ||
      post.will_save_change_to_title? || post.will_save_change_to_user_id? ||
      post.will_save_change_to_status? || post.will_save_change_to_verified?
    post.save! if post.changed? || body_changed

    tag_records = data[:tags].map { |name| Tag.find_or_create_by!(name: name) }
    post.tags = tag_records unless post.tag_ids.sort == tag_records.map(&:id).sort
  end

  # Rich-text-only edits do not trigger the Post model's indexing callbacks.
  if body_changed && !searchable_fields_changed
    PostSearchIndexJob.perform_later(post.id)
    post.enqueue_embedding_index
  end
end

puts "  #{Tag.count} tags"
puts "  #{Post.count} posts"
puts "Done! ✓"
