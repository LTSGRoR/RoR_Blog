class Users::SessionsController < Devise::SessionsController
  # After successful sign in, set the session locale to the user's preferred locale
  # so subsequent redirects use the correct language.
  def create
    super do |resource|
      if resource && resource.respond_to?(:locale) && resource.locale.present?
        session[:locale] = resource.locale.to_s
        I18n.locale = resource.locale.to_s
        Rails.logger.info("[SessionsController#create] set session[:locale]=#{session[:locale]} for user_id=#{resource.id}")
      end
    end
  end
end
