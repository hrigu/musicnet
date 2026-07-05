require "rails_helper"

RSpec.describe "Settings", type: :request do
  fixtures :users

  before { sign_in users(:one) }

  describe "GET /settings/edit" do
    it "liefert Erfolg und zeigt die aktuelle Kategorie vorausgewählt" do
      users(:one).update!(active_playlist_category: "blues")

      get edit_settings_path

      expect(response).to have_http_status(:success)
      selected = Nokogiri::HTML(response.body).at_css("input[name='user[active_playlist_category]'][checked]")
      expect(selected[:value]).to eq("blues")
    end
  end

  describe "PATCH /settings" do
    it "speichert die neue Kategorie und leitet mit Bestätigung weiter" do
      patch settings_path, params: { user: { active_playlist_category: "fusion" } }

      expect(response).to redirect_to(edit_settings_path)
      follow_redirect!
      expect(response.body).to include("gespeichert")
      expect(users(:one).reload.active_playlist_category).to eq("fusion")
    end

    it "lehnt einen ungültigen Wert ab" do
      patch settings_path, params: { user: { active_playlist_category: "quatsch" } }

      expect(users(:one).reload.active_playlist_category).to_not eq("quatsch")
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
