# Ensure ActionText body changes keep Post Searchkick documents fresh.
module SearchkickActionTextCallbacks
  extend ActiveSupport::Concern

  included do
    after_commit :reindex_post_search_document
  end

  private

  def reindex_post_search_document
    return unless record.is_a?(Post)

    record.reindex(mode: :async)
  end
end

Rails.application.config.to_prepare do
  unless ActionText::RichText < SearchkickActionTextCallbacks
    ActionText::RichText.include(SearchkickActionTextCallbacks)
  end
end
