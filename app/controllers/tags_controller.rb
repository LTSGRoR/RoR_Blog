class TagsController < ApplicationController
  before_action :authenticate_user!, only: [ :create ]

  def index
    q = params[:q].to_s.strip
    tags = if q.present?
      begin
        Tag.search(q, fields: [ { name: :word_start } ], limit: 20, load: false)
           .map { |t| { id: t.id, name: t.name } }
      rescue StandardError => e
        Rails.logger.warn("Searchkick unavailable: #{e.class} - #{e.message}")
        []
      end
    else
      Tag.order(:name).limit(20).pluck(:id, :name).map { |id, name| { id: id, name: name } }
    end

    render json: tags
  end

  def create
    name = params[:name].to_s.strip.downcase
    return render json: { error: "name required" }, status: :unprocessable_entity if name.blank?

    tag = Tag.find_or_create_by(name: name)
    return render json: { error: tag.errors.full_messages.to_sentence }, status: :unprocessable_entity if tag.invalid?

    render json: { id: tag.id, name: tag.name }, status: :created
  rescue ActiveRecord::RecordNotUnique
    # Lost a unique-index race while creating the tag; the winning row exists
    # now, so return it instead of a 500.
    tag = Tag.find_by(name: name)
    if tag
      render json: { id: tag.id, name: tag.name }, status: :created
    else
      render json: { error: "Could not create tag" }, status: :unprocessable_entity
    end
  end
end
