# frozen_string_literal: true

require "rails_helper"

RSpec.describe LocationNameResolver do
  def stub_nominatim_response(code:, body: nil)
    response = instance_double(Net::HTTPResponse, code:, body: body&.to_json)
    http = instance_double(Net::HTTP, request: response)
    allow(Net::HTTP).to receive(:start) { |*_args, &block| block.call(http) }
  end

  before { described_class.last_request_at = nil }

  it "gibt nil zurueck, wenn Koordinaten fehlen" do
    expect(described_class.resolve(latitude: nil, longitude: nil)).to be_nil
  end

  it "extrahiert den ersten passenden Ortsnamen aus der Adressantwort" do
    stub_nominatim_response(code: "200", body: { "address" => { "suburb" => "Altstadt", "city" => "Zürich" } })

    expect(described_class.resolve(latitude: 47.376887, longitude: 8.541694)).to eq("Zürich")
  end

  it "faellt auf ein groeberes Adressfeld zurueck, wenn kein feineres vorhanden ist" do
    stub_nominatim_response(code: "200", body: { "address" => { "state" => "Zürich" } })

    expect(described_class.resolve(latitude: 47.4, longitude: 8.5)).to eq("Zürich")
  end

  it "liefert nil ohne Fehler, wenn der Dienst nicht erfolgreich antwortet" do
    stub_nominatim_response(code: "500")

    expect(described_class.resolve(latitude: 47.4, longitude: 8.5)).to be_nil
  end

  it "liefert nil ohne Fehler, wenn die Anfrage eine Exception wirft" do
    allow(Net::HTTP).to receive(:start).and_raise(Errno::ECONNREFUSED)

    expect(described_class.resolve(latitude: 47.4, longitude: 8.5)).to be_nil
  end

  it "verwendet einen bereits aufgeloesten Ort fuer (gerundet) gleiche Koordinaten statt eines neuen Aufrufs" do
    user = User.create!(email: "rspec-location-cache@example.com", password: "password123")
    album = Album.create!(name: "Album loc-cache", spotify_id: "alb-loc-cache")
    track = Track.create!(name: "RSpec Location Cache", spotify_id: "loc-cache-1", album:, duration_ms: 200_000)
    DjSessionPlayback.create!(
      user:, track:, played_at: Time.current, latitude: 47.376888, longitude: 8.541695, location_name: "Zürich"
    )
    allow(Net::HTTP).to receive(:start)

    result = described_class.resolve(latitude: 47.376887, longitude: 8.541694)

    aggregate_failures do
      expect(result).to eq("Zürich")
      expect(Net::HTTP).not_to have_received(:start)
    end
  end
end
