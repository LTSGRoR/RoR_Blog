class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  include Pundit

  # Rescue from authorization errors and show a friendly message.
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  before_action :set_locale
  before_action :configure_permitted_parameters, if: :devise_controller?

  def default_url_options
    { locale: I18n.locale }
  end

  private

  def set_locale
    locale = params[:locale]&.to_sym
    I18n.locale = I18n.available_locales.include?(locale) ? locale : I18n.default_locale
  end

  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore
    flash[:alert] = t("errors.not_authorized")
    redirect_to(request.referer || root_path)
  end

  def configure_permitted_parameters
    added_attrs = [:name, :avatar]
    devise_parameter_sanitizer.permit(:sign_up, keys: added_attrs)
    devise_parameter_sanitizer.permit(:account_update, keys: added_attrs)
  end
end
