# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def index?
    user&.admin?
  end

  def ban?
    can_manage_target?
  end

  def unban?
    can_manage_target?
  end

  def suspend?
    can_manage_target?
  end

  def unsuspend?
    can_manage_target?
  end

  private

  def can_manage_target?
    user&.admin? && !record.admin?
  end
end
