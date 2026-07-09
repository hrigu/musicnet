# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Track cover", type: :request do
  fixtures :users

  let(:downloads_dir) { Rails.root.join("downloads/tracks") }

  def create_track(name:, spotify_id:)
    album = Album.create!(name: "Album #{spotify_id}", spotify_id: "alb-#{spotify_id}")
    Track.create!(name: name, spotify_id: spotify_id, album: album, duration_ms: 200_000)
  end

  def with_download_fixture(file_name, fixture_name)
    FileUtils.mkdir_p(downloads_dir)
    FileUtils.cp(Rails.root.join("spec/fixtures/files", fixture_name), downloads_dir.join(file_name))
    yield
  ensure
    FileUtils.rm_f(downloads_dir.join(file_name))
  end

  before do
    sign_in users(:one)
  end

  describe "GET /tracks/:id" do
    it "zeigt das Cover neben dem Titel, wenn der Track heruntergeladen wurde" do
      track = create_track(name: "RSpec Cover Show", spotify_id: "trk-cover-show")

      with_download_fixture("RSpec Artist - RSpec Cover Show.m4a", "cover_embedded.m4a") do
        get track_path(track)
      end

      image = Nokogiri::HTML(response.body).at_css("img[src='#{cover_track_path(track)}']")
      aggregate_failures do
        expect(image).to be_present
        expect(image[:onerror]).to eq("this.remove()")
      end
    end

    it "zeigt kein Cover-Tag, wenn der Track noch nicht heruntergeladen wurde" do
      track = create_track(name: "RSpec Cover Missing Show", spotify_id: "trk-cover-missing-show")

      get track_path(track)

      expect(response.body).to_not include(%(src="#{cover_track_path(track)}"))
    end
  end

  describe "GET /tracks/:id/cover" do
    it "liefert das eingebettete Cover mit korrektem Content-Type" do
      track = create_track(name: "RSpec Cover Endpoint", spotify_id: "trk-cover-endpoint")

      with_download_fixture("RSpec Artist - RSpec Cover Endpoint.m4a", "cover_embedded.m4a") do
        get cover_track_path(track)
      end

      aggregate_failures do
        expect(response).to have_http_status(:success)
        expect(response.media_type).to eq("image/png")
        expect(response.body.bytesize).to be_positive
      end
    end

    it "liefert 404 ohne heruntergeladene Datei" do
      track = create_track(name: "RSpec Cover No File", spotify_id: "trk-cover-no-file")

      get cover_track_path(track)

      expect(response).to have_http_status(:not_found)
    end

    it "liefert 404, wenn die Datei kein eingebettetes Cover hat" do
      track = create_track(name: "RSpec Cover None Endpoint", spotify_id: "trk-cover-none-endpoint")

      with_download_fixture("RSpec Artist - RSpec Cover None Endpoint.m4a", "silence.m4a") do
        get cover_track_path(track)
      end

      expect(response).to have_http_status(:not_found)
    end
  end
end
