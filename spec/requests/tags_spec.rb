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
end
