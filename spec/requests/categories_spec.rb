# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Categories", type: :request do
  fixtures :users

  before { sign_in users(:one) }

  describe "GET /categories" do
    it "zeigt alle Kategorien mit ihren Tags" do
      category = Category.create!(name: "RSpec Emotion")
      category.tags.create!(name: "RSpec Traurig", aliases: "sad")

      get categories_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("RSpec Emotion")
      expect(response.body).to include("RSpec Traurig")
    end
  end

  describe "POST /categories" do
    it "legt eine neue Kategorie an und leitet zum Index weiter" do
      post categories_path, params: { category: { name: "RSpec Neue Kategorie" } }

      expect(response).to redirect_to(categories_path)
      expect(Category.find_by(name: "RSpec Neue Kategorie")).to be_present
    end

    it "rendert das Formular erneut mit Fehlermeldung bei fehlendem Namen" do
      post categories_path, params: { category: { name: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /categories/:id" do
    it "aktualisiert die Kategorie" do
      category = Category.create!(name: "RSpec Alt")

      patch category_path(category), params: { category: { name: "RSpec Neu" } }

      expect(response).to redirect_to(categories_path)
      expect(category.reload.name).to eq("RSpec Neu")
    end

    it "setzt eine Farbe" do
      category = Category.create!(name: "RSpec Farbe setzen")

      patch category_path(category), params: { category: { color: "#4a90d9" } }

      expect(category.reload.color).to eq("#4a90d9")
    end

    it "entfernt die Farbe wieder (neutrale Badges)" do
      category = Category.create!(name: "RSpec Farbe entfernen", color: "#4a90d9")

      patch category_path(category), params: { category: { color: "" } }

      expect(category.reload.color).to be_blank
    end

    it "rendert das Formular erneut mit Fehlermeldung bei ungültiger Farbe" do
      category = Category.create!(name: "RSpec Farbe ungültig")

      patch category_path(category), params: { category: { color: "not-a-color" } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(category.reload.color).to be_blank
    end
  end

  describe "GET /categories/new und /categories/:id/edit" do
    it "zeigt keinen Farbwähler beim Anlegen (natives color-Feld könnte keine Farbe nicht abbilden)" do
      get new_category_path

      expect(response.body).to_not include('type="color"')
    end

    it "zeigt den Farbwähler beim Bearbeiten" do
      category = Category.create!(name: "RSpec Bearbeiten")

      get edit_category_path(category)

      expect(response.body).to include('type="color"')
    end
  end

  describe "DELETE /categories/:id" do
    it "löscht die Kategorie inkl. ihrer Tags" do
      category = Category.create!(name: "RSpec Löschen")
      tag = category.tags.create!(name: "RSpec Tag", aliases: "x")

      delete category_path(category)

      expect(response).to redirect_to(categories_path)
      expect(Tag.find_by(id: tag.id)).to be_nil
    end
  end

  describe "Navbar" do
    it "zeigt einen Link auf die Kategorien-Seite" do
      get tracks_path

      expect(response.body).to include(%(href="#{categories_path}"))
    end
  end
end
