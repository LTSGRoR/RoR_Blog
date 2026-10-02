class Admin::TagsController < ApplicationController
  before_action :authenticate_user!
  before_action -> { authorize Tag, :manage? }
  before_action :set_tag, except: [ :index, :search ]

  def index
    @query = params[:q].to_s.strip
    @filter = params[:filter].presence_in(%w[all unused]) || "all"
    @total_count = Tag.count
    unused = Tag.where.missing(:taggings, :post_revision_taggings)
    @unused_count = unused.count
    scope = @filter == "unused" ? unused : Tag.all
    scope = scope.where("tags.name ILIKE ?", "%#{Tag.sanitize_sql_like(@query)}%") if @query.present?
    @tags = scope.select(
      "tags.*",
      "(SELECT COUNT(*) FROM taggings WHERE taggings.tag_id = tags.id) AS posts_count",
      "(SELECT COUNT(*) FROM post_revision_taggings WHERE post_revision_taggings.tag_id = tags.id) AS revisions_count"
    ).order(:name).page(params[:page]).per(20)
  end

  def search
    query = params[:q].to_s.strip
    return render json: [] if query.blank?

    tags = Tag.where.not(id: params[:exclude_id]).order(:name)
    tags = tags.where("name ILIKE ?", "%#{Tag.sanitize_sql_like(query)}%") if query.present?
    render json: tags.limit(20).pluck(:id, :name).map { |id, name| { id: id, name: name } }
  end

  def edit
    load_usage
  end

  def update
    if @tag.with_lock { @tag.update(params.require(:tag).permit(:name)) }
      redirect_to admin_tags_path, notice: t("admin.tags.renamed"), status: :see_other
    else
      load_usage
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    @tag.errors.add(:name, :taken)
    load_usage
    render :edit, status: :unprocessable_entity
  end

  def merge
    target = Tag.find_by(name: params[:target_name].to_s.strip.downcase)
    raise ArgumentError, t("admin.tags.choose_target") unless target && target != @tag

    MergeTags.call(source: @tag, target: target)
    redirect_to admin_tags_path, notice: t("admin.tags.merged"), status: :see_other
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    @tag.errors.add(:base, e.message)
    load_usage
    render :edit, status: :unprocessable_entity
  end

  def destroy
    @tag.with_lock { @tag.destroy! }
    redirect_to admin_tags_path, notice: t("admin.tags.deleted"), status: :see_other
  end

  private

  def set_tag
    @tag = Tag.find(params[:id])
  end

  def load_usage
    @tag_label = @tag.name_in_database
    @posts_count = @tag.posts.count
    @revisions_count = @tag.post_revisions.count
    @posts = @tag.posts.order(updated_at: :desc).page(params[:posts_page]).per(10)
    @revisions = @tag.post_revisions.includes(:post).order(updated_at: :desc).page(params[:revisions_page]).per(10)
  end
end
