class SettingsController < ApplicationController
  def edit
    @libraries = Library.order(:name)
  end

  def update
    if current_user.update(settings_params)
      redirect_to edit_settings_path, notice: "Einstellungen gespeichert."
    else
      redirect_to edit_settings_path, alert: current_user.errors.full_messages.to_sentence
    end
  end

  private

  def settings_params
    params.require(:user).permit(:active_library_id)
  end
end
