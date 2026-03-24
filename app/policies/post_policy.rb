class PostPolicy < ApplicationPolicy
  # Anyone can view published posts; authors may view their own drafts.
  def show?
    return true if record.published?
    return false unless user
    user.admin? || record.user == user
  end

  def create?
    user.present?
  end

  def update?
    user.present? && (user.admin? || record.user == user)
  end

  def destroy?
    user.present? && (user.admin? || record.user == user)
  end

  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      elsif user
        scope.where("status = ? OR user_id = ?", Post.statuses[:published], user.id)
      else
        scope.where(status: Post.statuses[:published])
      end
    end
  end
end
