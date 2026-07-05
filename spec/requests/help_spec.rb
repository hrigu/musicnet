require "rails_helper"

RSpec.describe "Help", type: :request do
  fixtures :users

  before { sign_in users(:one) }

  describe "GET /help/suche-syntax" do
    it "rendert den Hilfeartikel zur DSL-Suche als HTML" do
      get help_path(page: "suche-syntax")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("playlist:")
      expect(response.body).to include("genre:pop OR genre:techno")
    end
  end

  describe "GET /help/installation" do
    it "rendert die Installationsanleitung als HTML" do
      get help_path(page: "installation")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Spotify-Credentials")
      expect(response.body).to include("127.0.0.1:3001")
    end
  end

  describe "GET /help/:page mit unbekanntem Slug" do
    it "liefert 404 statt eines Server-Fehlers" do
      get help_path(page: "unbekannt")

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "Navbar" do
    it "zeigt ein Hilfe-Dropdown mit einem Eintrag Suche, der auf den Hilfeartikel verlinkt" do
      get tracks_path

      dropdown = Nokogiri::HTML(response.body).at_css(".nav-item.dropdown")
      expect(dropdown.text).to include("Hilfe")
      link = dropdown.at_css("a[href='#{help_path(page: 'suche-syntax')}']")
      expect(link.text.strip).to eq("Suche")
    end

    it "zeigt zusätzlich einen Eintrag Installation, der auf den Hilfeartikel verlinkt" do
      get tracks_path

      dropdown = Nokogiri::HTML(response.body).at_css(".nav-item.dropdown")
      link = dropdown.at_css("a[href='#{help_path(page: 'installation')}']")
      expect(link.text.strip).to eq("Installation")
    end
  end
end
