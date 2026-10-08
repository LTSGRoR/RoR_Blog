class PostPolicy < ApplicationPolicy
  def show?
    return true if user&.admin?
    return false if record.user.banned?
    return true if record.published? && record.verified?
    return false unless user
    user.admin? || record.user == user
  end

  def create?
    user.present?
  end

  def update?
    return false unless user.present?
    return record.user == user if user.admin?
    record.user == user && (record.draft? || !record.verified?)
  end

  def verify?
    user.present? && user.admin? && record.published?
  end

  def unverify?
    user.present? && user.admin? && record.published?
  end

  def request_revision?
    user.present? && record.user == user && record.verified? && record.published?
  end

  def moderation_index?
    user&.admin?
  end

  def destroy?
    user.present? && (user.admin? || (record.user == user && (record.draft? || !record.verified?)))
  end

  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      elsif user
        scope.publicly_visible
             .or(scope.where(user_id: user.id))
      else
        scope.publicly_visible
      end
    end
  end
end
