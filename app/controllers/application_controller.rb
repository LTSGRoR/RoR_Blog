class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  include Pundit::Authorization

  # Rescue from authorization errors and show a friendly message.
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  # Rescue common request-level failures so they degrade into a friendly
  # redirect/JSON error instead of a raw 500 page.
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActionController::ParameterMissing, with: :render_unprocessable
  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable
  rescue_from ActiveRecord::StaleObjectError do
    respond_to do |format|
      format.html { redirect_back fallback_location: root_path, alert: "This content changed. Reload before trying again.", status: :see_other }
      format.any { head :conflict }
    end
  end

  before_action :set_locale
  before_action :configure_permitted_parameters, if: :devise_controller?

  private

  def set_locale
    locale = params[:locale] ||
             session[:locale] ||
             (current_user&.locale) ||
             I18n.default_locale

    if I18n.available_locales.map(&:to_s).include?(locale.to_s)
      I18n.locale = locale
      session[:locale] = locale
    else
      I18n.locale = I18n.default_locale
    end
  end

  def default_url_options
    { locale: I18n.locale }
  end

  def user_not_authorized(_exception)
    flash[:alert] = t("errors.not_authorized")
    respond_to do |format|
      # safe_back_path keeps us from bouncing to auth pages, off-site referers,
      # or the same page we came from (which would loop forever).
      format.html { redirect_to(helpers.safe_back_path(root_path)) }
      format.turbo_stream { head :forbidden }
      format.json { head :forbidden }
      format.any { redirect_to(helpers.safe_back_path(root_path)) }
    end
  end

  def render_not_found(exception)
    log_rescued_exception(exception)
    message = t("errors.not_found", default: "Record not found.")
    respond_to do |format|
      format.html { redirect_to(helpers.safe_back_path(root_path), alert: message, status: :see_other) }
      format.turbo_stream { head :not_found }
      format.json { render json: { error: message }, status: :not_found }
      format.any { head :not_found }
    end
  end

  def render_unprocessable(exception)
    log_rescued_exception(exception)
    message = exception_message_for(exception)
    respond_to do |format|
      format.html { redirect_back(fallback_location: helpers.safe_back_path(root_path), alert: message) }
      format.turbo_stream { head :unprocessable_entity }
      format.json { render json: { error: message }, status: :unprocessable_entity }
      format.any { head :unprocessable_entity }
    end
  end

  def exception_message_for(exception)
    record = exception.respond_to?(:record) ? exception.record : nil
    return record.errors.full_messages.to_sentence if record&.errors&.any?

    exception.message
  end

  def log_rescued_exception(exception)
    Rails.logger.warn("[#{self.class.name}] rescued #{exception.class.name}: #{exception.message}")
  end

  def configure_permitted_parameters
    added_attrs = [ :name, :avatar, :profile_title, :bio ]
    devise_parameter_sanitizer.permit(:sign_up, keys: added_attrs)
    devise_parameter_sanitizer.permit(:account_update, keys: added_attrs)
  end
end
