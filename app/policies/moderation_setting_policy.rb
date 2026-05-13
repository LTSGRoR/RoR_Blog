class ModerationSettingPolicy < ApplicationPolicy
  def edit?
    user&.admin?
  end

  def update?
    user&.admin?
  end
end
