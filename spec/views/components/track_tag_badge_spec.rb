# frozen_string_literal: true

require "rails_helper"

RSpec.describe "components/_track_tag_badge" do
  it "zeigt einen Entfernen-Button, der auf track_tag_path per DELETE zielt (Intent 89)" do
    category = Category.create!(name: "RSpec Badge Entfernen Kategorie")
    album = Album.create!(name: "Album Badge Entfernen", spotify_id: "badge-remove-1")
    track = Track.create!(name: "Track Badge Entfernen", spotify_id: "badge-remove-1", album:, duration_ms: 200_000)
    tag = category.tags.create!(name: "RSpec Badge Entfernen Tag", aliases: "x")
    track_tag = TrackTag.create!(track:, tag:, strength: 5)

    html = ApplicationController.render(partial: "components/track_tag_badge", locals: { track_tag: })

    aggregate_failures do
      expect(html).to include(%(action="/track_tags/#{track_tag.id}"))
      expect(html).to include('name="_method" value="delete"')
      expect(html).to include(">×<")
    end
  end
end
