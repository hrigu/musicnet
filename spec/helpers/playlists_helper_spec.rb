# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlaylistsHelper, type: :helper do
  describe "#playlist_short_name" do
    it "ersetzt 'fusion'/'blues' und entfernt Leerzeichen" do
      playlist = Playlist.new(name: "Fusion Dark")

      expect(helper.playlist_short_name(playlist)).to eq("F_Dark")
    end
  end

  describe "#playlist_color_class" do
    it "gibt 'bg-dark' zurück, wenn der Name mit 4 Ziffern beginnt (DJ-Playlist)" do
      playlist = Playlist.new(name: "2024 DJ Set")

      expect(helper.playlist_color_class(playlist)).to eq("bg-dark")
    end

    it "gibt einen Wert aus CONTEXT zurück, wenn es keine DJ-Playlist ist" do
      playlist = Playlist.new(name: "Fusion Dark")

      expect(PlaylistsHelper::CONTEXT).to include(helper.playlist_color_class(playlist))
    end
  end

  describe "#all_tracks_downloaded?" do
    it "gibt true zurück, wenn alle Tracks einen track_path haben" do
      pt1 = instance_double(PlaylistTrack, track: instance_double(Track, track_path: "/a.m4a"))
      pt2 = instance_double(PlaylistTrack, track: instance_double(Track, track_path: "/b.m4a"))

      expect(helper.all_tracks_downloaded?([pt1, pt2])).to be true
    end

    it "gibt false zurück, wenn mindestens ein Track keinen track_path hat" do
      pt1 = instance_double(PlaylistTrack, track: instance_double(Track, track_path: "/a.m4a"))
      pt2 = instance_double(PlaylistTrack, track: instance_double(Track, track_path: nil))

      expect(helper.all_tracks_downloaded?([pt1, pt2])).to be false
    end

    it "gibt true zurück für eine leere Playlist" do
      expect(helper.all_tracks_downloaded?([])).to be true
    end
  end
end
