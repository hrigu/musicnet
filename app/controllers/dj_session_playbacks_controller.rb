# frozen_string_literal: true

class DjSessionPlaybacksController < ApplicationController
  def create
    playback = current_user.dj_session_playbacks.create!(playback_params.merge(played_at: Time.current))
    ResolveDjSessionPlaybackLocationJob.perform_later(playback) if playback.latitude && playback.longitude

    render json: { id: playback.id }, status: :created
  end

  private

  def playback_params
    params.require(:dj_session_playback).permit(:track_id, :latitude, :longitude, :location_accuracy_meters)
  end
end
