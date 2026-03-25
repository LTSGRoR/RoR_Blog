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

    def attach_avatar(resource)
      return unless params[:user].present? && params[:user][:avatar].present?
      resource.avatar.attach(params[:user][:avatar])
    end
  end
end
