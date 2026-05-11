module AiModeration
  class ReviewPayloadBuilder
    class << self
      def for_post(post)
        {
          type: "post",
          locale: I18n.locale.to_s,
          post_id: post.id,
          title: post.title,
          body: post.body.to_plain_text,
          tags: post.tags.pluck(:name)
        }
      end

      def for_revision(revision)
        {
          type: "post_revision",
          locale: I18n.locale.to_s,
          revision_id: revision.id,
          post_id: revision.post_id,
          title: revision.title,
          body: revision.body.to_plain_text,
          tags: revision.tags.pluck(:name)
        }
      end
    end
  end
end
