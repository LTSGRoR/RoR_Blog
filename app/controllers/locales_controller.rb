class LocalesController < ApplicationController
  skip_before_action :set_locale, only: [ :create ]

  def create
    raw    = params[:chosen_locale] || params[:locale]
    locale = raw&.to_sym

    if locale.present? && I18n.available_locales.include?(locale)
      I18n.locale = locale

      session[:locale] = locale
      persist_user_locale(locale) if current_user

      locale_label = t("language_name.#{locale}", default: t("locale_switcher.#{locale}", default: locale.to_s.upcase))
      flash[:notice] = t("locale.changed", locale_name: locale_label)

      redirect_back_with_locale(locale)
    else
      I18n.locale = I18n.default_locale
      flash[:alert] = t("locale.unsupported", locale_name: raw)
      redirect_back fallback_location: root_path(locale: I18n.default_locale), status: :see_other
    end
  end

  private

  # Best-effort persistence of the locale preference; a failed save (e.g. the
  # user record no longer validates) must not break the locale switch itself.
  def persist_user_locale(locale)
    return if current_user.update(locale: locale)

    Rails.logger.warn(
      "LocalesController: failed to persist locale=#{locale} for user=#{current_user.id}: #{current_user.errors.full_messages.to_sentence}"
    )
  end

  def redirect_back_with_locale(locale)
    fallback = root_path(locale: locale)
    referer  = request.referer

    return redirect_to fallback, status: :see_other if referer.blank?

    begin
      uri = URI.parse(referer)
    rescue URI::InvalidURIError
      return redirect_to fallback, status: :see_other
    end

    new_path = uri.path.sub(%r{\A/(en|vi|ja)(/|\z)}, "/#{locale}\\2")
    new_path = "/#{locale}#{uri.path}" unless new_path.start_with?("/#{locale}")
    redirect_to new_path + (uri.query ? "?#{uri.query}" : ""), status: :see_other
  end
end
