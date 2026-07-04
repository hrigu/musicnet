# frozen_string_literal: true

require "rails_helper"

RSpec.describe QueueEntry, type: :model do
  let(:album) { Album.create!(spotify_id: "alb-qe-1", name: "Album") }

  def create_track(name:, spotify_id:)
    Track.create!(name: name, spotify_id: spotify_id, album: album, duration_ms: 200_000)
  end

  it "ist ungültig ohne Track" do
    queue_entry = QueueEntry.new

    expect(queue_entry).not_to be_valid
    expect(queue_entry.errors[:track]).to be_present
  end

  describe ".full?" do
    it "ist falsch, solange weniger als 5 Eintraege existieren" do
      4.times { |n| QueueEntry.create!(track: create_track(name: "Track #{n}", spotify_id: "qe-#{n}")) }

      expect(QueueEntry).not_to be_full
    end

    it "ist wahr ab 5 Eintraegen" do
      5.times { |n| QueueEntry.create!(track: create_track(name: "Track #{n}", spotify_id: "qe-#{n}")) }

      expect(QueueEntry).to be_full
    end
  end
end
