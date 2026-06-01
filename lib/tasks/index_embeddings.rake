namespace :embeddings do
  desc "Enqueue embedding jobs for all posts (async)."
  task enqueue_posts: :environment do
    puts "Enqueuing IndexPostEmbeddingsJob for posts without embeddings..."
    Post.find_each do |post|
      IndexPostEmbeddingsJob.perform_later(post.id)
    end
    puts "Enqueued jobs for all posts."
  end

  desc "Run embedding indexing for all posts immediately (blocking)."
  task run_posts: :environment do
    interval_seconds = 1
    puts "Indexing embeddings for posts (blocking) with #{interval_seconds}s interval..."
    Post.find_each do |post|
      IndexPostEmbeddingsJob.perform_now(post.id)
      sleep(interval_seconds)
    end
    puts "Completed embedding indexing for all posts."
  end
end
