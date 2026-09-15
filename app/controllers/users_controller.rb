class UsersController < ApplicationController
  before_action :authenticate_user!, only: [ :index, :ban, :unban, :suspend, :unsuspend ]
  before_action :set_profile_user, only: :show
  before_action :set_managed_user, only: [ :ban, :unban, :suspend, :unsuspend ]

  def show
    verified_posts = @user.posts.published.where(verified: true)

    @posts = verified_posts.includes(:rich_text_body).order(created_at: :desc).limit(3)
    # The "published" and "verified" stats have always rendered the same
    # verified-posts total; compute it once instead of running COUNT twice.
    @posts_count = @verified_count = verified_posts.count
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

    status_counts = summarize_status_counts(users_scope)
    @total_count = status_counts[:total]
    @banned_count = status_counts[:banned]
    @suspended_count = status_counts[:suspended]
    @active_count = status_counts[:active]

    @users = users_scope.page(params[:page]).per(10)

    if turbo_frame_request?
      render turbo_stream: [
        turbo_stream.replace(
          "users_table",
          partial: "users/users_table",
          locals: { users: @users }
        ),
        turbo_stream.replace(
          "users_summary",
          partial: "users/users_summary",
          locals: { total_count: @total_count, active_count: @active_count, suspended_count: @suspended_count, banned_count: @banned_count }
        ),
        turbo_stream.update(
          "flash_messages",
          partial: "shared/flash"
        )
      ]
    else
      render "users/index"
    end
  end

  def ban
    authorize @user, :ban?

    @user.update!(banned_at: Time.current, suspended_until: nil, suspended_time_zone: nil)
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

    if @user.banned?
      redirect_to users_path, alert: t("users.admin.flash.unban_first", default: "Unban user before suspending.")
      return
    end

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
  rescue ArgumentError
    # Malformed datetime values raise inside parse_suspended_until; degrade to
    # a friendly alert instead of a 500.
    Rails.logger.warn("UsersController#suspend: unparseable suspended_until param #{params[:suspended_until].inspect}")
    redirect_to users_path, alert: t("users.admin.flash.invalid_suspend_date")
  end

  def unsuspend
    authorize @user, :unsuspend?
    @user.update!(suspended_until: nil, suspended_time_zone: nil)

    broadcast_user_and_summary(@user)
    redirect_to users_path, notice: t("users.admin.flash.unsuspended", email: @user.email), status: :see_other
  end

  private

  def set_profile_user
    # NOTE: no `includes(:posts)` — it used to load every post of the profile
    # owner (plus their attachments) to render at most three of them.
    @user = User.includes(avatar_attachment: :blob).find_by(id: params[:id])
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
  end

  def broadcast_user_and_summary(user)
    begin
      # The display order and the status counters do not depend on the locale,
      # but the partials have to be rendered once per locale channel. Compute
      # them once here instead of repeating the work inside the loop.
      order_ids = User.order(created_at: :desc).pluck(:id)
      row_index = order_ids.index(user.id)
      status_counts = summarize_status_counts(User.all)

      I18n.available_locales.each do |locale|
        I18n.with_locale(locale) do
          Turbo::StreamsChannel.broadcast_replace_to "users_#{locale}",
            target: "user_#{user.id}",
            partial: "users/user_row",
            locals: { user: user, i: row_index }

          Turbo::StreamsChannel.broadcast_replace_to "users_#{locale}",
            target: "users_summary",
            partial: "users/users_summary",
            locals: {
              total_count: status_counts[:total],
              active_count: status_counts[:active],
              suspended_count: status_counts[:suspended],
              banned_count: status_counts[:banned]
            }
        end
      end
    rescue => e
      Rails.logger.error "UsersController#broadcast_user_and_summary: broadcast failed for user=#{user.id} — #{e.message}"
    end
  end

  def summarize_status_counts(scope)
    # One round trip instead of four COUNT queries; `active` is derived exactly
    # like ClearExpiredSuspensionsJob#broadcast_summary does (banned and
    # suspended are mutually exclusive by validation). The ORDER BY on an
    # aggregate would be invalid SQL, so drop it here (callers paginate off a
    # separate, ordered scope).
    now = scope.connection.quote(Time.current)

    total, banned, suspended = scope.unscope(:order).pick(
      Arel.sql("COUNT(*)"),
      Arel.sql("COUNT(*) FILTER (WHERE users.banned_at IS NOT NULL)"),
      Arel.sql("COUNT(*) FILTER (WHERE users.banned_at IS NULL AND users.suspended_until > #{now})")
    )

    { total: total, banned: banned, suspended: suspended, active: total - banned - suspended }
  end
end
