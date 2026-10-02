class MergeTags
  def self.call(source:, target:)
    raise ArgumentError, "Choose a different existing tag." if source.id == target.id

    Tag.transaction do
      locked_tags = Tag.where(id: [ source.id, target.id ]).order(:id).lock.to_a
      raise ActiveRecord::RecordNotFound unless locked_tags.size == 2
      # Use association callbacks so post indexes and revision versions stay current.
      source.taggings.find_each do |tagging|
        Tagging.find_or_create_by!(post_id: tagging.post_id, tag_id: target.id)
        tagging.destroy!
      end
      source.post_revision_taggings.find_each do |tagging|
        PostRevisionTagging.find_or_create_by!(post_revision_id: tagging.post_revision_id, tag_id: target.id)
        tagging.destroy!
      end
      source.destroy!
    end
  end
end
