# frozen_string_literal: true

require "rails_helper"

RSpec.describe "tracks/_spotify_import_progress_entry" do
  def build_track(spotify_id:)
    album = Album.create!(name: "Album #{spotify_id}", spotify_id: "alb-#{spotify_id}")
    Track.create!(name: "RSpec Progress Entry #{spotify_id}", spotify_id:, album:, duration_ms: 200_000)
  end

  def render_entry(track:, success:)
    ApplicationController.render(partial: "tracks/spotify_import_progress_entry", locals: { track:, success: })
  end

  it "zeigt einen Fehlschlag farblich als alert-danger, nicht ungefärbt" do
    track = build_track(spotify_id: "progress-entry-fail")

    html = render_entry(track:, success: false)

    aggregate_failures do
      expect(html).to include("alert-danger")
      expect(html).to include("Download fehlgeschlagen")
    end
  end

  it "zeigt einen Erfolg farblich als alert-success" do
    track = build_track(spotify_id: "progress-entry-success")

    html = render_entry(track:, success: true)

    aggregate_failures do
      expect(html).to include("alert-success")
      expect(html).to include("heruntergeladen")
    end
  end
end
