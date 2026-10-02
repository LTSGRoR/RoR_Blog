class TagPolicy < ApplicationPolicy
  def manage?
    user&.admin?
  end
end
