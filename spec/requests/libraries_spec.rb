# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Libraries", type: :request do
  fixtures :users

  before { sign_in users(:one) }

  describe "GET /libraries" do
    it "zeigt alle Bibliotheken mit Name und Stichwort" do
      Library.create!(name: "Blues", keyword: "blues")

      get libraries_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Blues")
      expect(response.body).to include("blues")
    end
  end

  describe "GET /libraries/new" do
    it "zeigt das Formular für eine neue Bibliothek" do
      get new_library_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /libraries" do
    it "legt eine neue Bibliothek an und leitet zum Index weiter" do
      post libraries_path, params: { library: { name: "Deep House", keyword: "house" } }

      expect(response).to redirect_to(libraries_path)
      expect(Library.find_by(name: "Deep House").keyword).to eq("house")
    end

    it "rendert das Formular erneut mit Fehlermeldung bei fehlendem Namen" do
      post libraries_path, params: { library: { name: "", keyword: "house" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(Library.find_by(keyword: "house")).to be_nil
    end
  end

  describe "GET /libraries/:id/edit" do
    it "zeigt das Formular vorausgefüllt an" do
      library = Library.create!(name: "Blues", keyword: "blues")

      get edit_library_path(library)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Blues")
    end
  end

  describe "PATCH /libraries/:id" do
    it "aktualisiert die Bibliothek und leitet zum Index weiter" do
      library = Library.create!(name: "Blues", keyword: "blues")

      patch library_path(library), params: { library: { name: "Blues Nights", keyword: "blues" } }

      expect(response).to redirect_to(libraries_path)
      expect(library.reload.name).to eq("Blues Nights")
    end

    it "rendert das Formular erneut mit Fehlermeldung bei fehlendem Stichwort" do
      library = Library.create!(name: "Blues", keyword: "blues")

      patch library_path(library), params: { library: { name: "Blues", keyword: "" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(library.reload.keyword).to eq("blues")
    end
  end

  describe "DELETE /libraries/:id" do
    it "löscht die Bibliothek und leitet zum Index weiter" do
      library = Library.create!(name: "Blues", keyword: "blues")

      delete library_path(library)

      expect(response).to redirect_to(libraries_path)
      expect(Library.find_by(id: library.id)).to be_nil
    end
  end

  describe "Navbar" do
    it "zeigt einen Link auf die Bibliotheken-Seite" do
      get tracks_path

      expect(response.body).to include(%(href="#{libraries_path}"))
    end
  end
end
