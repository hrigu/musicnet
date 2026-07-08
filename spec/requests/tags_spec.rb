# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Tags", type: :request do
  fixtures :users

  before { sign_in users(:one) }

  describe "GET /categories/:category_id/tags/new" do
    it "zeigt das Formular für einen neuen Tag" do
      category = Category.create!(name: "RSpec Kategorie")

      get new_category_tag_path(category)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /categories/:category_id/tags" do
    it "legt einen neuen Tag in der Kategorie an" do
      category = Category.create!(name: "RSpec Kategorie")

      post category_tags_path(category), params: { tag: { name: "RSpec Tag", aliases: "x, y" } }

      expect(response).to redirect_to(categories_path)
      tag = Tag.find_by(name: "RSpec Tag")
      expect(tag.category).to eq(category)
      expect(tag.alias_list).to eq(%w[x y])
    end

    it "rendert das Formular erneut mit Fehlermeldung bei fehlenden Aliasen" do
      category = Category.create!(name: "RSpec Kategorie")

      post category_tags_path(category), params: { tag: { name: "RSpec Tag", aliases: "" } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /tags/:id" do
    it "aktualisiert einen Tag, auch die Kategorie-Zuordnung" do
      category_a = Category.create!(name: "RSpec Kategorie A")
      category_b = Category.create!(name: "RSpec Kategorie B")
      tag = category_a.tags.create!(name: "RSpec Tag", aliases: "x")

      patch tag_path(tag), params: { tag: { category_id: category_b.id } }

      expect(response).to redirect_to(categories_path)
      expect(tag.reload.category).to eq(category_b)
    end
  end

  describe "DELETE /tags/:id" do
    it "löscht den Tag" do
      category = Category.create!(name: "RSpec Kategorie")
      tag = category.tags.create!(name: "RSpec Tag", aliases: "x")

      delete tag_path(tag)

      expect(response).to redirect_to(categories_path)
      expect(Tag.find_by(id: tag.id)).to be_nil
    end
  end

  describe "GET /tags/search" do
    it "liefert passende Tags inkl. Kategorie als JSON" do
      category = Category.create!(name: "RSpec Emotion Suche")
      tag = category.tags.create!(name: "RSpec Traurig Suche", aliases: "x")
      category.tags.create!(name: "RSpec Happy Suche", aliases: "y")

      get search_tags_path(term: "traurig")

      json = JSON.parse(response.body)
      expect(json).to eq([{ "id" => tag.id, "name" => tag.name, "category" => category.name }])
    end

    it "liefert eine leere Liste bei leerem Suchbegriff" do
      get search_tags_path(term: "")

      expect(JSON.parse(response.body)).to eq([])
    end

    it "blendet Tags aus für die Neuzuordnung ausgeblendeten Kategorien aus" do
      sichtbar = Category.create!(name: "RSpec Sichtbar Suche")
      sichtbar.tags.create!(name: "RSpec Sichtbares Tag", aliases: "x")
      ausgeblendet = Category.create!(name: "RSpec Ausgeblendet Suche", hidden_for_assignment: true)
      ausgeblendet.tags.create!(name: "RSpec Ausgeblendetes Tag", aliases: "y")

      get search_tags_path(term: "RSpec")

      names = JSON.parse(response.body).map { |t| t["name"] }
      expect(names).to include("RSpec Sichtbares Tag")
      expect(names).to_not include("RSpec Ausgeblendetes Tag")
    end

    it "blendet mit track_id bereits zugewiesene Tags aus" do
      album = Album.create!(name: "Album", spotify_id: "alb-search-1")
      track = Track.create!(name: "Track", spotify_id: "trk-search-1", album: album, duration_ms: 200_000)
      category = Category.create!(name: "RSpec Emotion Track-Suche")
      zugewiesen = category.tags.create!(name: "RSpec Zugewiesen Suche", aliases: "x")
      nicht_zugewiesen = category.tags.create!(name: "RSpec Frei Suche", aliases: "y")
      TrackTag.create!(track: track, tag: zugewiesen, strength: 5)

      get search_tags_path(term: "RSpec", track_id: track.id)

      names = JSON.parse(response.body).map { |t| t["name"] }
      expect(names).to include(nicht_zugewiesen.name)
      expect(names).to_not include(zugewiesen.name)
    end
  end
end
