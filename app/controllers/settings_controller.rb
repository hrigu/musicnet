# frozen_string_literal: true

class SettingsController < ApplicationController
  def edit
    @libraries = Library.order(:name)
  end

  def update
    if current_user.update(user_update_params)
      redirect_to edit_settings_path, notice: "Einstellungen gespeichert."
    else
      redirect_to edit_settings_path, alert: current_user.errors.full_messages.to_sentence
    end
  end

  private

  # Checkboxen senden nur die ANGEHAKTEN (also sichtbaren) Spalten - hidden_track_columns
  # speichert aber die ausgeblendeten. visible_track_columns existiert nur als Formular-Parameter,
  # keine echte Spalte (siehe die Umrechnung unten).
  def settings_params
    params.require(:user).permit(:active_library_id, visible_track_columns: [])
  end

  # Nur anfassen, wenn der Parameter ueberhaupt mitgeschickt wurde - sonst wuerde z.B. ein
  # Request, der nur active_library_id aendert, hidden_track_columns unbeabsichtigt auf "alle
  # Spalten ausblenden" zuruecksetzen (visible_track_columns waere dann ein leeres Array). Das
  # normale Formular schickt dank des Leer-Hidden-Fields (settings/edit.html.erb) den Parameter
  # immer mit, auch wenn keine Checkbox angehakt ist.
  def user_update_params
    base = settings_params.except(:visible_track_columns)
    return base unless params[:user].key?(:visible_track_columns)

    visible = (settings_params[:visible_track_columns] || []).reject(&:blank?)
    hidden = Track::OPTIONAL_COLUMNS.keys - visible
    base.merge(hidden_track_columns: hidden)
  end
end
