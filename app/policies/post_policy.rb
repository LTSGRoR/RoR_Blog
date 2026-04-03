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
    return false unless user.present?
    return false if user.admin?
    record.user == user && !record.verified?
  end

  def verify?
    user.present? && user.admin? && record.published?
  end

  def unverify?
    user.present? && user.admin? && record.published?
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
