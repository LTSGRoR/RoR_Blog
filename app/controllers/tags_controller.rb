class TagsController < ApplicationController
  before_action :authenticate_user!, only: [:create]

  # GET /tags?q=term
  def index
    q = params[:q].to_s.strip
    tags = if q.present?
      Tag.where("name ILIKE ?", "#{q}%").order(:name).limit(20)
    else
      Tag.order(:name).limit(20)
    end

    render json: tags.map { |t| { id: t.id, name: t.name } }
  end

  # POST /tags
  # params: { name: 'rails' }
  def create
    name = params[:name].to_s.strip
    return render json: { error: 'name required' }, status: :unprocessable_entity if name.blank?

    tag = Tag.find_or_create_by(name: name.downcase)
    render json: { id: tag.id, name: tag.name }, status: :created
  end
end
