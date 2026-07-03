# frozen_string_literal: true

require "rails_helper"

RSpec.describe Playlist, type: :model do
  describe "#name_path_ready" do
    it "entfernt Leerzeichen aus dem Namen" do
      playlist = Playlist.new(name: "Fusion Dark")

      expect(playlist.name_path_ready).to eq("FusionDark")
    end
  end
end
