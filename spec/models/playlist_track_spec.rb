# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlaylistTrack, type: :model do
  it "ist ungültig ohne Playlist" do
    playlist_track = PlaylistTrack.new(track: Track.new)

    expect(playlist_track).not_to be_valid
    expect(playlist_track.errors[:playlist]).to be_present
  end

  it "ist ungültig ohne Track" do
    playlist_track = PlaylistTrack.new(playlist: Playlist.new)

    expect(playlist_track).not_to be_valid
    expect(playlist_track.errors[:track]).to be_present
  end
end
