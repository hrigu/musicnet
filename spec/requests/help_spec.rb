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

  describe "GET /help/bedienung" do
    it "rendert die Bedienungsanleitung als HTML" do
      get help_path(page: "bedienung")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Cue-/Vorhörkanal")
      expect(response.body).to include("create_crates_lists")
    end
  end

  describe "GET /help/diary" do
    it "rendert das Diary als HTML" do
      get help_path(page: "diary")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Essentia")
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

    it "zeigt zusätzlich einen Eintrag Bedienung, der auf den Hilfeartikel verlinkt" do
      get tracks_path

      dropdown = Nokogiri::HTML(response.body).at_css(".nav-item.dropdown")
      link = dropdown.at_css("a[href='#{help_path(page: 'bedienung')}']")
      expect(link.text.strip).to eq("Bedienung")
    end

    it "zeigt zusätzlich einen Eintrag Diary, der auf den Hilfeartikel verlinkt" do
      get tracks_path

      dropdown = Nokogiri::HTML(response.body).at_css(".nav-item.dropdown")
      link = dropdown.at_css("a[href='#{help_path(page: 'diary')}']")
      expect(link.text.strip).to eq("Diary")
    end

    it "zeigt alle vier Hilfeartikel" do
      get tracks_path

      dropdown = Nokogiri::HTML(response.body).at_css(".nav-item.dropdown")
      links = dropdown.css("a.dropdown-item").map { |link| link.text.strip }
      expect(links).to eq(%w[Suche Installation Bedienung Diary])
    end
  end
end
