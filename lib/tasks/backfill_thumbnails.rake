# Backfill thumbnails for posts using placeholder images.
# Usage:
#  bundle exec rails posts:backfill_thumbnails COUNT=50 SCOPE=published FORCE=false START_ID=100
# ENV options:
#  - COUNT: max number of posts to process (default: 100)
#  - SCOPE: 'all' or 'published' (default: 'published')
#  - FORCE: 'true' to replace existing thumbnails (default: false)
#  - START_ID: only process posts with id >= START_ID

require 'open-uri'

namespace :posts do
  desc "Backfill thumbnails for posts"
  task backfill_thumbnails: :environment do
    count = (ENV['COUNT'] || 100).to_i
    scope = (ENV['SCOPE'] || 'published')
    force = ENV['FORCE'] == 'true'
    start_id = ENV['START_ID'] && ENV['START_ID'].to_i

    posts_scope = case scope
    when 'all'
      Post.all
    else
      Post.where(status: Post.statuses[:published], verified: true)
    end

    posts_scope = posts_scope.where('posts.id >= ?', start_id) if start_id

    unless force
      # select posts that do not yet have a thumbnail attached
      posts_scope = posts_scope.left_joins(:thumbnail_attachment).where(active_storage_attachments: { id: nil })
    end

    posts = posts_scope.order(created_at: :desc).limit(count)

    if posts.none?
      puts "No posts found to process (scope=#{scope}, force=#{force})."
      next
    end

    puts "Processing #{posts.size} posts (scope=#{scope}, force=#{force})..."

    posts.find_each do |post|
      begin
        # Use picsum.photos as a neutral placeholder image source. Size can be adjusted.
        url = "https://picsum.photos/1400/800?random=#{post.id}"
        filename = "post-#{post.id}.jpg"

        URI.open(url) do |image_file|
          post.thumbnail.attach(io: image_file, filename: filename, content_type: image_file.content_type || 'image/jpeg')
        end

        puts "Attached thumbnail for post ##{post.id} (#{post.title.inspect})"
        sleep 0.15
      rescue StandardError => e
        puts "Failed to attach thumbnail for post ##{post.id}: #{e.class} - #{e.message}"
      end
    end

    puts "Done."
  end
end
