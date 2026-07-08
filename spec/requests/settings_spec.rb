# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Settings", type: :request do
  fixtures :users

  before { sign_in users(:one) }

  describe "GET /settings/edit" do
    it "liefert Erfolg und zeigt die aktuelle Bibliothek vorausgewählt" do
      blues = Library.create!(name: "Blues", keyword: "blues")
      Library.create!(name: "Fusion", keyword: "fusion")
      users(:one).update!(active_library: blues)

      get edit_settings_path

      expect(response).to have_http_status(:success)
      selected = Nokogiri::HTML(response.body).at_css("input[name='user[active_library_id]'][checked]")
      expect(selected[:value]).to eq(blues.id.to_s)
    end

    it "zeigt alle vorhandenen Bibliotheken zur Auswahl" do
      Library.create!(name: "Blues", keyword: "blues")
      Library.create!(name: "Deep House", keyword: "house")

      get edit_settings_path

      expect(response.body).to include("Blues")
      expect(response.body).to include("Deep House")
    end
  end

  describe "PATCH /settings" do
    it "speichert die neue Bibliothek und leitet mit Bestätigung weiter" do
      fusion = Library.create!(name: "Fusion", keyword: "fusion")

      patch settings_path, params: { user: { active_library_id: fusion.id } }

      expect(response).to redirect_to(edit_settings_path)
      follow_redirect!
      expect(response.body).to include("gespeichert")
      expect(users(:one).reload.active_library).to eq(fusion)
    end

    it "erlaubt das Zurücksetzen auf 'Alle' (leerer Wert)" do
      fusion = Library.create!(name: "Fusion", keyword: "fusion")
      users(:one).update!(active_library: fusion)

      patch settings_path, params: { user: { active_library_id: "" } }

      expect(users(:one).reload.active_library).to be_nil
    end

    it "lehnt eine nicht existierende Bibliotheks-Id ab" do
      patch settings_path, params: { user: { active_library_id: 999_999 } }

      expect(users(:one).reload.active_library_id).to be_nil
    end
  end

  describe "GET /settings/edit - Spalten (Intent 80)" do
    it "zeigt alle optionalen Spalten als angehakte Checkboxen, solange nichts ausgeblendet ist" do
      get edit_settings_path

      html = Nokogiri::HTML(response.body)
      Track::OPTIONAL_COLUMNS.each_key do |key|
        checkbox = html.at_css("#visible_column_#{key}")
        expect(checkbox[:checked]).to be_present
      end
    end

    it "zeigt eine ausgeblendete Spalte nicht angehakt" do
      users(:one).update!(hidden_track_columns: ["playlists"])

      get edit_settings_path

      checkbox = Nokogiri::HTML(response.body).at_css("#visible_column_playlists")
      expect(checkbox[:checked]).to be_nil
    end
  end

  describe "PATCH /settings - Spalten (Intent 80)" do
    it "blendet nur die nicht angehakten Spalten aus" do
      patch settings_path, params: { user: { visible_track_columns: Track::OPTIONAL_COLUMNS.keys - ["playlists"] } }

      expect(users(:one).reload.hidden_track_columns).to eq(["playlists"])
    end

    it "blendet alle Spalten aus, wenn keine Checkbox angehakt ist (leeres Array)" do
      patch settings_path, params: { user: { visible_track_columns: [""] } }

      expect(users(:one).reload.hidden_track_columns).to match_array(Track::OPTIONAL_COLUMNS.keys)
    end

    it "lässt hidden_track_columns unverändert, wenn nur die Bibliothek geändert wird" do
      fusion = Library.create!(name: "Fusion", keyword: "fusion")
      users(:one).update!(hidden_track_columns: ["playlists"])

      patch settings_path, params: { user: { active_library_id: fusion.id } }

      expect(users(:one).reload.hidden_track_columns).to eq(["playlists"])
    end

    it "wirkt sich sofort auf die Tracks-Tabelle aus" do
      album = Album.create!(name: "Album", spotify_id: "alb-settings-cols")
      Track.create!(name: "RSpec Spalten Track", spotify_id: "trk-settings-cols", album: album, duration_ms: 200_000)
      patch settings_path, params: { user: { visible_track_columns: Track::OPTIONAL_COLUMNS.keys - ["genre"] } }

      get tracks_path

      expect(response.body).to_not include(">Genre<")
    end
  end

  describe "Navbar" do
    it "zeigt einen Link 'Einstellungen'" do
      get tracks_path

      link = Nokogiri::HTML(response.body).at_css("nav a[href='#{edit_settings_path}']")
      expect(link.text.strip).to eq("Einstellungen")
    end
  end
end
