# frozen_string_literal: true

require "rails_helper"

RSpec.describe RelatedTracksFinder do
  def create_track(name, genre: nil, energy: nil, tempo: nil)
    album = Album.create!(name: "Album #{name}", spotify_id: "alb-rtf-#{name}")
    audio_features = {}
    audio_features["energy"] = energy if energy
    audio_features["tempo"] = tempo if tempo
    Track.create!(name: name, spotify_id: "trk-rtf-#{name}", album: album, duration_ms: 200_000,
                  genre: genre, audio_features: audio_features.presence)
  end

  it "findet Tracks mit gemeinsamem Tag, sortiert nach Naehe der Staerke" do
    origin = create_track("Origin")
    close_match = create_track("Close Match")
    far_match = create_track("Far Match")
    category = Category.create!(name: "RSpec Emotion RTF")
    tag = category.tags.create!(name: "RSpec Froehlich", aliases: "x")

    TrackTag.create!(track: origin, tag: tag, strength: 8)
    TrackTag.create!(track: close_match, tag: tag, strength: 9)
    TrackTag.create!(track: far_match, tag: tag, strength: 2)

    results = RelatedTracksFinder.new(origin).call

    expect(results.map { |r| r[:track] }).to eq([close_match, far_match])
    expect(results.first[:score]).to be > results.second[:score]
  end

  it "liefert die Punkte-Herkunft pro gemeinsamem Tag, damit die Punktezahl nachvollziehbar ist" do
    origin = create_track("Origin RTF Breakdown")
    match = create_track("Match RTF Breakdown")
    emotion = Category.create!(name: "RSpec Emotion RTF Breakdown")
    quality = Category.create!(name: "RSpec Qualitaet RTF Breakdown")
    emotion_tag = emotion.tags.create!(name: "RSpec Froehlich Breakdown", aliases: "x")
    quality_tag = quality.tags.create!(name: "RSpec Tanzbar Breakdown", aliases: "y")

    TrackTag.create!(track: origin, tag: emotion_tag, strength: 8)
    TrackTag.create!(track: match, tag: emotion_tag, strength: 9)
    TrackTag.create!(track: origin, tag: quality_tag, strength: 5)
    TrackTag.create!(track: match, tag: quality_tag, strength: 3)

    result = RelatedTracksFinder.new(origin).call.first

    expect(result[:score]).to eq(9 + 8)
    contributions = result[:contributions].sort_by(&:label)
    expect(contributions.map(&:label)).to eq(["RSpec Froehlich Breakdown", "RSpec Tanzbar Breakdown"].sort)
    froehlich = contributions.find { |c| c.label == "RSpec Froehlich Breakdown" }
    expect(froehlich.base_value).to eq(8)
    expect(froehlich.candidate_value).to eq(9)
    expect(froehlich.points).to eq(9)
    expect(froehlich.weight).to eq(1.0)
  end

  it "ignoriert Tracks ohne gemeinsames Tag" do
    origin = create_track("Origin 2")
    unrelated = create_track("Unrelated")
    category = Category.create!(name: "RSpec Emotion RTF 2")
    tag = category.tags.create!(name: "RSpec Traurig RTF", aliases: "x")
    TrackTag.create!(track: origin, tag: tag, strength: 5)

    results = RelatedTracksFinder.new(origin).call

    expect(results.map { |r| r[:track] }).to_not include(unrelated)
  end

  it "schliesst sich selbst aus" do
    origin = create_track("Origin 3")
    category = Category.create!(name: "RSpec Emotion RTF 3")
    tag = category.tags.create!(name: "RSpec Tag RTF 3", aliases: "x")
    TrackTag.create!(track: origin, tag: tag, strength: 5)

    results = RelatedTracksFinder.new(origin).call

    expect(results.map { |r| r[:track] }).to_not include(origin)
  end

  it "liefert eine leere Liste, wenn der Ausgangstrack keine Tags hat und keine Attribute gewaehlt sind" do
    origin = create_track("Origin 4")

    expect(RelatedTracksFinder.new(origin).call).to eq([])
  end

  it "laesst ein selteneres, ebenso stark passendes Tag nicht von einem haeufigeren verdraengen" do
    origin = create_track("Origin RTF Diversity")
    category = Category.create!(name: "RSpec Musikstil RTF Diversity")
    popular_tag = category.tags.create!(name: "RSpec Jazz Diversity", aliases: "x")
    rare_tag = category.tags.create!(name: "RSpec Walzer Diversity", aliases: "y")
    TrackTag.create!(track: origin, tag: popular_tag, strength: 5)
    TrackTag.create!(track: origin, tag: rare_tag, strength: 5)

    # Absichtlich zuerst viele Treffer fuer das haeufige Tag anlegen (wie im echten Fall: Jazz per
    # automatischer Playlist-Zuordnung an viele Tracks, Walzer nur manuell an wenige) - ohne feste
    # Diversifizierung wuerden diese wegen niedrigerer ids/Erstellungsreihenfolge die Rangliste
    # komplett fuellen, bevor ueberhaupt ein Walzer-Treffer drankommt.
    15.times do |i|
      popular_match = create_track("Popular Match #{i}")
      TrackTag.create!(track: popular_match, tag: popular_tag, strength: 5)
    end
    rare_matches = 3.times.map do |i|
      rare_match = create_track("Rare Match #{i}")
      TrackTag.create!(track: rare_match, tag: rare_tag, strength: 5)
      rare_match
    end

    results = RelatedTracksFinder.new(origin, category_ids: [category.id]).call

    expect(results.map { |r| r[:track] } & rare_matches).to_not be_empty
  end

  describe "Attribut Genre" do
    it "findet Tracks mit gleichem Genre, wenn aktiviert" do
      origin = create_track("Origin RTF Genre", genre: "Jazz")
      match = create_track("Match RTF Genre", genre: "Jazz")
      other = create_track("Other RTF Genre", genre: "Rock")

      results = RelatedTracksFinder.new(origin, attribute_weights: { "genre" => 1.0 }).call

      expect(results.map { |r| r[:track] }).to include(match)
      expect(results.map { |r| r[:track] }).to_not include(other)
    end

    it "ignoriert das Genre, wenn nicht aktiviert" do
      origin = create_track("Origin RTF Genre Off", genre: "Jazz")
      create_track("Match RTF Genre Off", genre: "Jazz")

      expect(RelatedTracksFinder.new(origin).call).to eq([])
    end
  end

  describe "Attribut Bibliothek" do
    it "findet Tracks mit gemeinsamer Bibliothek, wenn aktiviert" do
      origin = create_track("Origin RTF Library")
      match = create_track("Match RTF Library")
      other = create_track("Other RTF Library")
      library = Library.create!(name: "RSpec Bibliothek RTF", keyword: "rtf-lib")
      playlist_a = Playlist.create!(spotify_id: "pl-rtf-lib-a", name: "Playlist A")
      playlist_b = Playlist.create!(spotify_id: "pl-rtf-lib-b", name: "Playlist B")
      playlist_a.libraries << library
      playlist_b.libraries << library
      PlaylistTrack.create!(playlist: playlist_a, track: origin, added_at: Time.current)
      PlaylistTrack.create!(playlist: playlist_b, track: match, added_at: Time.current)
      PlaylistTrack.create!(playlist: Playlist.create!(spotify_id: "pl-rtf-lib-c", name: "Playlist C"), track: other,
                            added_at: Time.current)

      results = RelatedTracksFinder.new(origin, attribute_weights: { "library" => 1.0 }).call

      expect(results.map { |r| r[:track] }).to include(match)
      expect(results.map { |r| r[:track] }).to_not include(other)
    end
  end

  describe "Attribut Energie" do
    it "gewichtet aehnliche Energie hoeher als weit auseinanderliegende" do
      origin = create_track("Origin RTF Energy", energy: 0.8)
      close = create_track("Close RTF Energy", energy: 0.82)
      far = create_track("Far RTF Energy", energy: 0.2)

      results = RelatedTracksFinder.new(origin, attribute_weights: { "energy" => 1.0 }).call

      close_score = results.find { |r| r[:track] == close }[:score]
      far_score = results.find { |r| r[:track] == far }[:score]
      expect(close_score).to be > far_score
    end
  end

  describe "Attribut Tempo" do
    it "gewichtet aehnliches Tempo hoeher als weit auseinanderliegendes" do
      origin = create_track("Origin RTF Tempo", tempo: 120)
      close = create_track("Close RTF Tempo", tempo: 122)
      far = create_track("Far RTF Tempo", tempo: 80)

      results = RelatedTracksFinder.new(origin, attribute_weights: { "tempo" => 1.0 }).call

      close_score = results.find { |r| r[:track] == close }[:score]
      far_score = results.find { |r| r[:track] == far }[:score]
      expect(close_score).to be > far_score
    end
  end

  describe "Gewichtung" do
    it "vervielfacht den Punktbeitrag eines Attributs um den angegebenen Faktor" do
      origin = create_track("Origin RTF Weight", genre: "Jazz")
      match = create_track("Match RTF Weight", genre: "Jazz")

      unweighted = RelatedTracksFinder.new(origin, attribute_weights: { "genre" => 1.0 }).call
      weighted = RelatedTracksFinder.new(origin, attribute_weights: { "genre" => 2.5 }).call

      unweighted_score = unweighted.find { |r| r[:track] == match }[:score]
      weighted_score = weighted.find { |r| r[:track] == match }[:score]
      expect(weighted_score).to eq(unweighted_score * 2.5)
    end

    it "verwendet Gewicht 1.0, wenn kein oder ein ungueltiges Gewicht angegeben wird" do
      origin = create_track("Origin RTF Weight Default", genre: "Jazz")
      create_track("Match RTF Weight Default", genre: "Jazz")

      results = RelatedTracksFinder.new(origin, attribute_weights: { "genre" => "" }).call

      expect(results.first[:contributions].first.weight).to eq(1.0)
    end
  end

  describe "#active_comparison_count" do
    it "zaehlt die fuer die Berechnung verwendeten eigenen Tags des Ausgangstracks" do
      origin = create_track("Origin RTF BaseCount")
      category = Category.create!(name: "RSpec Emotion RTF BaseCount")
      tag_a = category.tags.create!(name: "RSpec Tag A BaseCount", aliases: "x")
      tag_b = category.tags.create!(name: "RSpec Tag B BaseCount", aliases: "y")
      TrackTag.create!(track: origin, tag: tag_a, strength: 5)
      TrackTag.create!(track: origin, tag: tag_b, strength: 5)

      finder = RelatedTracksFinder.new(origin)
      finder.call

      expect(finder.active_comparison_count).to eq(2)
    end

    it "zaehlt zusaetzlich aktivierte Attribute mit, sofern der Ausgangstrack dafuer einen Wert hat" do
      origin = create_track("Origin RTF BaseCount 2", genre: "Jazz", tempo: 120)

      finder = RelatedTracksFinder.new(origin, attribute_weights: { "genre" => 1.0, "tempo" => 1.0, "energy" => 1.0 })
      finder.call

      # Genre + Tempo zaehlen (Wert vorhanden), Energie nicht (kein Wert am Ausgangstrack)
      expect(finder.active_comparison_count).to eq(2)
    end
  end

  describe "#additional_tied_count" do
    it "ist 0, wenn keine Kuerzung auf MAX_RESULTS stattgefunden hat" do
      origin = create_track("Origin RTF Tied None")
      match = create_track("Match RTF Tied None")
      category = Category.create!(name: "RSpec Emotion RTF Tied None")
      tag = category.tags.create!(name: "RSpec Tag RTF Tied None", aliases: "x")
      TrackTag.create!(track: origin, tag: tag, strength: 5)
      TrackTag.create!(track: match, tag: tag, strength: 5)

      finder = RelatedTracksFinder.new(origin)
      finder.call

      expect(finder.additional_tied_count).to eq(0)
    end

    it "zaehlt Treffer mit derselben Punktzahl wie der letzte angezeigte, die aber abgeschnitten wurden" do
      origin = create_track("Origin RTF Tied")
      category = Category.create!(name: "RSpec Emotion RTF Tied")
      tag = category.tags.create!(name: "RSpec Tag RTF Tied", aliases: "x")
      TrackTag.create!(track: origin, tag: tag, strength: 5)

      # 12 Treffer mit identischer Staerke (= identische Punktzahl) - mehr als MAX_RESULTS (10)
      12.times do |i|
        match = create_track("Match RTF Tied #{i}")
        TrackTag.create!(track: match, tag: tag, strength: 5)
      end

      finder = RelatedTracksFinder.new(origin)
      finder.call

      expect(finder.additional_tied_count).to eq(2)
    end
  end

  describe "category_ids" do
    it "beruecksichtigt nur gemeinsame Tags aus den gewaehlten Kategorien" do
      origin = create_track("Origin 5")
      match_in_category = create_track("Match In Category")
      match_outside_category = create_track("Match Outside Category")
      emotion = Category.create!(name: "RSpec Emotion RTF 5")
      quality = Category.create!(name: "RSpec Qualitaet RTF 5")
      emotion_tag = emotion.tags.create!(name: "RSpec Froehlich RTF 5", aliases: "x")
      quality_tag = quality.tags.create!(name: "RSpec Tanzbar RTF 5", aliases: "y")

      TrackTag.create!(track: origin, tag: emotion_tag, strength: 5)
      TrackTag.create!(track: origin, tag: quality_tag, strength: 5)
      TrackTag.create!(track: match_in_category, tag: emotion_tag, strength: 5)
      TrackTag.create!(track: match_outside_category, tag: quality_tag, strength: 5)

      results = RelatedTracksFinder.new(origin, category_ids: [emotion.id]).call

      expect(results.map { |r| r[:track] }).to include(match_in_category)
      expect(results.map { |r| r[:track] }).to_not include(match_outside_category)
    end

    it "beruecksichtigt alle Kategorien, wenn keine gewaehlt ist" do
      origin = create_track("Origin 6")
      match = create_track("Match 6")
      category = Category.create!(name: "RSpec Emotion RTF 6")
      tag = category.tags.create!(name: "RSpec Tag RTF 6", aliases: "x")
      TrackTag.create!(track: origin, tag: tag, strength: 5)
      TrackTag.create!(track: match, tag: tag, strength: 5)

      results = RelatedTracksFinder.new(origin, category_ids: []).call

      expect(results.map { |r| r[:track] }).to include(match)
    end
  end
end
