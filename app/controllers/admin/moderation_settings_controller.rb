class Admin::ModerationSettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_setting

  def edit
    authorize @setting
  end

  def update
    authorize @setting

    if @setting.update(setting_params)
      redirect_to edit_admin_moderation_setting_path, notice: t("admin.moderation_settings.flash.updated")
    else
      flash.now[:alert] = @setting.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_setting
    @setting = ModerationSetting.current
  end

  def setting_params
    params.require(:moderation_setting).permit(
      :provider,
      :ai_model,
      :auto_approve_threshold,
      :request_timeout_seconds,
      :max_retries,
      :auto_review_enabled,
      :new_post_instruction,
      :revision_instruction
    )
  end
end
