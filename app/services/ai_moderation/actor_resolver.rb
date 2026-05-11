module AiModeration
  class ActorResolver
    class << self
      def admin_user
        email = ENV["AI_MODERATION_ADMIN_EMAIL"].to_s.strip
        return User.admin.find_by(email: email) if email.present?

        User.admin.order(:id).first
      end
    end
  end
end
