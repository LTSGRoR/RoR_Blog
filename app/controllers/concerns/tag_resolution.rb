# frozen_string_literal: true

# Shared helpers for resolving human-typed tag names into Tag ids.
#
# Tag normalizes names (strip + downcase) in a before_save callback, so the
# lookup must use the downcased name. Using raw user input would miss the
# downcased row and then collide with the unique index on insert; on that
# race we retry the lookup and return the winner's id instead of bubbling
# an ActiveRecord::RecordNotUnique up as a 500.
module TagResolution
  extend ActiveSupport::Concern

  private

  def find_or_create_tag_id!(name)
    normalized = name.to_s.strip.downcase
    Tag.find_or_create_by!(name: normalized).id.to_s
  rescue ActiveRecord::RecordNotUnique
    Tag.find_by(name: normalized)&.id.to_s
  end
end
