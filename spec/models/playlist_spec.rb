# frozen_string_literal: true

require "rails_helper"

RSpec.describe Playlist, type: :model do
  describe "#short_name" do
    it "ersetzt 'fusion'/'blues' und entfernt Leerzeichen" do
      playlist = Playlist.new(name: "Fusion Dark")

      expect(playlist.short_name).to eq("F_Dark")
    end
  end

  describe "#color_class" do
    it "gibt 'bg-dark' zurück, wenn der Name mit 4 Ziffern beginnt (DJ-Playlist)" do
      playlist = Playlist.new(name: "2024 DJ Set")

      expect(playlist.color_class).to eq("bg-dark")
    end

    it "gibt einen Wert aus CONTEXT zurück, wenn es keine DJ-Playlist ist" do
      playlist = Playlist.new(name: "Fusion Dark")

      expect(Playlist::CONTEXT).to include(playlist.color_class)
    end
  end

  describe "#name_path_ready" do
    it "entfernt Leerzeichen aus dem Namen" do
      playlist = Playlist.new(name: "Fusion Dark")

      expect(playlist.name_path_ready).to eq("FusionDark")
    end
  end
end
