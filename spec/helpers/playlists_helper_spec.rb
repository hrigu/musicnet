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
end
