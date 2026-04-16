class PostRevisionPolicy < ApplicationPolicy
  def show?
    user&.admin?
  end

  def new?
    create?
  end

  def create?
    user.present? && record.post.user == user && record.post.verified? && record.post.published?
  end

  def edit?
    user.present? && record.author == user && (record.draft? || record.pending_review?)
  end

  def update?
    user.present? && record.author == user && record.draft?
  end

  def submit?
    user.present? && record.author == user && record.draft?
  end

  def withdraw?
    user.present? && record.author == user && record.pending_review?
  end

  def approve?
    user&.admin?
  end

  def reject?
    user&.admin?
  end

  def destroy?
    user&.admin?
  end

  class Scope < Scope
    def resolve
      return scope.where(author_id: user.id) if user.present? && !user.admin?
      return scope.all if user&.admin?

      scope.none
    end
  end
end