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

  describe "Navbar" do
    it "zeigt einen Link 'Einstellungen'" do
      get tracks_path

      link = Nokogiri::HTML(response.body).at_css("nav a[href='#{edit_settings_path}']")
      expect(link.text.strip).to eq("Einstellungen")
    end
  end
end
