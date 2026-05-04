class UsersController < ApplicationController
  before_action :authenticate_user!, only: [:index, :ban, :unban, :suspend, :unsuspend]
  before_action :set_profile_user, only: :show
  before_action :set_managed_user, only: [:ban, :unban, :suspend, :unsuspend]

  def show
    @posts = @user.posts.published.order(created_at: :desc).limit(3)
    @posts_count = @user.posts.published.count
    @verified_count = @user.posts.published.where(verified: true).count
  end

  def index
    authorize User

    @query = params[:q].to_s.strip
    @role = params[:role].to_s.presence
    @status = params[:status].to_s.presence

    users_scope = User.order(created_at: :desc)
    users_scope = users_scope.by_name(@query)
    users_scope = users_scope.by_role(@role)
    users_scope = users_scope.by_status(@status)

    # compute counts efficiently from the filtered scope (before pagination)
    total = users_scope.count
    banned = users_scope.where.not(banned_at: nil).count
    suspended = users_scope.where("suspended_until IS NOT NULL AND suspended_until > ?", Time.current).count
    active = total - banned - suspended

    @total_count = total
    @banned_count = banned
    @suspended_count = suspended
    @active_count = active

    @users = users_scope.page(params[:page]).per(10)
    respond_to do |format|
      format.html { render "users/index" }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            "admin_users_list",
            partial: "users/users_table",
            locals: { users: @users }
          ),
          turbo_stream.replace(
            "flash_messages",
            partial: "shared/flash"
          )
        ]
      end
    end
  end

  def ban
    authorize @user, :ban?

    @user.update!(banned_at: Time.current, suspended_until: nil)
    broadcast_user_and_summary(@user)
    redirect_to users_path, notice: t("users.admin.flash.banned", email: @user.email), status: :see_other
  end

  def unban
    authorize @user, :unban?

    @user.update!(banned_at: nil)
    broadcast_user_and_summary(@user)
    redirect_to users_path, notice: t("users.admin.flash.unbanned", email: @user.email), status: :see_other
  end

  def suspend
    authorize @user, :suspend?

    suspended_until = parse_suspended_until
    unless suspended_until&.future?
      redirect_to users_path, alert: t("users.admin.flash.invalid_suspend_date")
      return
    end
    # store canonical timezone name where possible; accept a sensible fallback
    tz_param = params[:suspend_time_zone].to_s.presence
    canonical_lookup = (defined?(TIMEZONE_ALIASES) && TIMEZONE_ALIASES[tz_param]) || tz_param
    zone = ActiveSupport::TimeZone[canonical_lookup] || ActiveSupport::TimeZone[tz_param]
    canonical_tz = zone&.name || Time.zone.name

    @user.update!(suspended_until: suspended_until, suspended_time_zone: canonical_tz, banned_at: nil)
    broadcast_user_and_summary(@user)
    redirect_to users_path, notice: t("users.admin.flash.suspended", email: @user.email, time: l(suspended_until, format: :short)), status: :see_other
  end

  def unsuspend
    authorize @user, :unsuspend?
    @user.update!(suspended_until: nil, suspended_time_zone: nil)

    broadcast_user_and_summary(@user)
    redirect_to users_path, notice: t("users.admin.flash.unsuspended", email: @user.email), status: :see_other
  end

  private

  def set_profile_user
    @user = User.includes(:posts).find_by(id: params[:id])
    unless @user
      redirect_to users_path, alert: "User not found." and return
    end
  end

  def set_managed_user
    @user = User.find_by(id: params[:id])
    unless @user
      redirect_to users_path, alert: "User not found." and return
    end
  end

  def parse_suspended_until
    return nil if params[:suspended_until].blank?
    # Support browser-provided IANA names and a few common aliases (e.g. Asia/Saigon)
    tz_param = params[:suspend_time_zone].to_s.presence
    canonical_lookup = (defined?(TIMEZONE_ALIASES) && TIMEZONE_ALIASES[tz_param]) || tz_param
    zone = ActiveSupport::TimeZone[canonical_lookup] || ActiveSupport::TimeZone[tz_param] || Time.zone

    raw = params[:suspended_until].to_s
    # HTML `datetime-local` posts values like "YYYY-MM-DDTHH:MM" (no zone).
    # Parse components and construct a zoned time to avoid ambiguous parsing.
    if raw =~ /\A(\d{4})-(\d{2})-(\d{2})[T\s](\d{2}):(\d{2})\z/
      y = $1.to_i; m = $2.to_i; d = $3.to_i; hh = $4.to_i; mm = $5.to_i
      return zone.local(y, m, d, hh, mm)
    end

    # Fallback to zone.parse for other formats
    zone.parse(raw)
  rescue ArgumentError
    nil
  end

  def broadcast_user_and_summary(user)
    begin
      order_ids = User.order(created_at: :desc).pluck(:id)

      Turbo::StreamsChannel.broadcast_replace_to "users",
        target: "user_#{user.id}",
        partial: "users/user_row",
        locals: { user: user, i: order_ids.index(user.id) }

      total = User.count
      banned = User.where.not(banned_at: nil).count
      suspended = User.where("suspended_until IS NOT NULL AND suspended_until > ?", Time.current).count
      active = total - banned - suspended

      Turbo::StreamsChannel.broadcast_replace_to "users",
        target: "users_summary",
        partial: "users/users_summary",
        locals: { total_count: total, active_count: active, suspended_count: suspended, banned_count: banned }
    rescue => e
      Rails.logger.error "UsersController#broadcast_user_and_summary: broadcast failed for user=#{user.id} — #{e.message}"
    end
  end
end
