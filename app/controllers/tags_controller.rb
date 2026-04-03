class TagsController < ApplicationController
  before_action :authenticate_user!, only: [:create]

  def index
    q = params[:q].to_s.strip
    tags = if q.present?
      begin
        Tag.search(q, fields: [{ name: :word_start }], limit: 20, load: false)
           .map { |t| { id: t.id, name: t.name } }
      rescue => e
        Rails.logger.warn("Searchkick unavailable: #{e.class} - #{e.message}")
        Tag.where("name ILIKE ?", "#{q}%").order(:name).limit(20)
           .pluck(:id, :name).map { |id, name| { id: id, name: name } }
      end
    else
      Tag.order(:name).limit(20).pluck(:id, :name).map { |id, name| { id: id, name: name } }
    end

    render json: tags
  end

  def create
    name = params[:name].to_s.strip
    return render json: { error: 'name required' }, status: :unprocessable_entity if name.blank?

    tag = Tag.find_or_create_by(name: name.downcase)
    render json: { id: tag.id, name: tag.name }, status: :created
  end
end
