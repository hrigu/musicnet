require "rails_helper"

RSpec.describe "Help", type: :request do
  fixtures :users

  before { sign_in users(:one) }

  describe "GET /help/suche-syntax" do
    it "rendert den Hilfeartikel zur DSL-Suche als HTML" do
      get search_syntax_help_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("playlist:")
      expect(response.body).to include("kein Leerzeichen")
    end
  end

  describe "Navbar" do
    it "zeigt ein Hilfe-Dropdown mit einem Eintrag Suche, der auf den Hilfeartikel verlinkt" do
      get tracks_path

      dropdown = Nokogiri::HTML(response.body).at_css(".nav-item.dropdown")
      expect(dropdown.text).to include("Hilfe")
      link = dropdown.at_css("a[href='#{search_syntax_help_path}']")
      expect(link.text.strip).to eq("Suche")
    end
  end
end
