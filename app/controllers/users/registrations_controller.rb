module Users
  class RegistrationsController < Devise::RegistrationsController
    # Attach uploaded avatar after create/update
    def create
      super do |resource|
        attach_avatar(resource)
      end
    end

    def update
      super do |resource|
        attach_avatar(resource)
      end
    end

    private

    def after_update_path_for(_resource)
      edit_user_registration_path
    end

    # Only require current_password when changing email or password.
    # For name/avatar-only updates, skip password verification entirely.
    def update_resource(resource, params)
      changing_sensitive = params[:password].present?

      if changing_sensitive
        resource.update_with_password(params)
      else
        params.delete(:current_password)
        resource.update_without_password(params)
      end
    end

    def attach_avatar(resource)
      return unless params[:user].present? && params[:user][:avatar].present?
      resource.avatar.attach(params[:user][:avatar])
    end
  end
end
