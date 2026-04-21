class Admin::UsersController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize User

    @query = params[:q].to_s.strip
    @role = params[:role].to_s.presence
    @status = params[:status].to_s.presence

    users_scope = User.order(created_at: :desc)
    users_scope = users_scope.by_name(@query)
    users_scope = users_scope.by_role(@role)
    users_scope = users_scope.by_status(@status)

    @users = users_scope.page(params[:page]).per(20)
    respond_to do |format|
      format.html { render "users/index" }
      format.turbo_stream {
      render turbo_stream: turbo_stream.replace(
        "admin_users_list",
        partial: "users/users_table",
        locals: { users: @users }
        )
      }
    end
  end 
end
