namespace :embeddings do
  desc "Enqueue embedding jobs for published + verified posts missing embeddings (async)."
  task enqueue_posts: :environment do
    scope = Post.where(status: Post.statuses[:published], verified: true, embedding: nil)
    puts "Enqueuing IndexPostEmbeddingsJob for #{scope.count} published + verified posts without embeddings..."
    scope.find_each do |post|
      IndexPostEmbeddingsJob.perform_later(post.id)
    end
    puts "Enqueued jobs for eligible posts."
  end

  desc "Run embedding indexing for all published + verified posts immediately (blocking)."
  task run_posts: :environment do
    interval_seconds = 1
    scope = Post.where(status: Post.statuses[:published], verified: true)
    puts "Indexing embeddings for #{scope.count} published + verified posts (blocking) with #{interval_seconds}s interval..."
    scope.find_each do |post|
      IndexPostEmbeddingsJob.perform_now(post.id)
      sleep(interval_seconds)
    end
    puts "Completed embedding indexing for eligible posts."
  end
end
