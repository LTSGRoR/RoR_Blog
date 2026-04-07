class UsersController < ApplicationController
  before_action :authenticate_user!, only: [:index, :ban, :unban, :suspend, :unsuspend]
  before_action :set_profile_user, only: :show
  before_action :set_managed_user, only: [:ban, :unban, :suspend, :unsuspend]

  def show
    @posts = @user.posts.published.order(created_at: :desc)
  end

  def index
    authorize User
    @users = User.order(created_at: :desc)
  end

  def ban
    authorize @user, :ban?

    @user.update!(banned_at: Time.current, suspended_until: nil)
    redirect_to users_path, notice: t("users.admin.flash.banned", email: @user.email)
  end

  def unban
    authorize @user, :unban?

    @user.update!(banned_at: nil)
    redirect_to users_path, notice: t("users.admin.flash.unbanned", email: @user.email)
  end

  def suspend
    authorize @user, :suspend?

    suspended_until = parse_suspended_until
    unless suspended_until&.future?
      redirect_to users_path, alert: t("users.admin.flash.invalid_suspend_date")
      return
    end

    @user.update!(suspended_until: suspended_until, banned_at: nil)
    redirect_to users_path, notice: t("users.admin.flash.suspended", email: @user.email, time: l(suspended_until, format: :short))
  end

  def unsuspend
    authorize @user, :unsuspend?

    @user.update!(suspended_until: nil)
    redirect_to users_path, notice: t("users.admin.flash.unsuspended", email: @user.email)
  end

  private

  def set_profile_user
    @user = User.includes(:posts).find(params[:id])
  end

  def set_managed_user
    @user = User.find(params[:id])
  end

  def parse_suspended_until
    return nil if params[:suspended_until].blank?

    Time.zone.parse(params[:suspended_until])
  rescue ArgumentError
    nil
  end
end
