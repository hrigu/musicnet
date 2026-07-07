# frozen_string_literal: true

# Berechnet TrackTag-Zuordnungen (Tag + Staerke) aus den Playlist-Namen neu (Intent 77/78).
# Bewusst NICHT Teil von BuildMusicNetService/dem Spotify-Sync - die Taxonomie (Category/Tag)
# wird im Admin-UI laufend angepasst, dieser Task muss darum beliebig oft erneut laufen koennen,
# ohne veraltete Zuordnungen stehen zu lassen. Pro Tag wird deshalb der volle Soll-Zustand neu
# berechnet und mit dem Ist-Zustand abgeglichen (Upsert + Loeschen ueberzaehliger Zeilen),
# statt Staerken nur zu erhoehen - sonst wuerde z.B. das Entfernen eines Alias oder einer
# Playlist alte, falsche Staerken fuer immer stehen lassen.
#
# Erkennt zusaetzlich (Intent 78) ein Datum am Anfang eines Playlist-Namens (z.B.
# "2023-12-01_Salsadancers") und legt dafuer automatisch einen Tag unter der Kategorie
# "Auftrittsdatum" an - anders als die uebrige, feste Taxonomie (Alias-Matching, siehe
# SeedCategoriesAndTags) ist die Menge moeglicher Daten nicht im Voraus aufzaehlbar. Die
# Playlist-zu-Datum-Zuordnung wird direkt per Regex bestimmt statt ueber Tag#matches_normalized_name?,
# damit ein kurzes Jahres-Tag ("2026") nicht faelschlich auch in praeziseren Daten
# ("2026-01-05...") mitmatcht - dieses Risiko haette ein generischer Wortgrenzen-Alias-Vergleich.
desc "berechnet TrackTag-Zuordnungen und Staerken aus Playlist-Namen neu"
task assign_track_tags: [:environment] do
  # Frequenzbasierte Staerke: je mehr matchende Playlists denselben Track x Tag ergeben, desto
  # sicherer die Zuordnung. Monoton, deckelt bei 3+ auf 10.
  strength_for_count = ->(n) { { 1 => 5, 2 => 7 }.fetch(n, 10) }

  date_prefix = /\A(\d{4})(?:[-_](\d{2}))?(?:[-_](\d{2}))?[-_ ]/
  extract_performance_date = lambda do |playlist_name|
    match = date_prefix.match(playlist_name)
    match && [match[1], match[2], match[3]].compact.join("-")
  end

  total_upserted = 0
  total_removed = 0

  # Berechnet fuer einen einzelnen Tag den vollen Soll-Zustand aus einer Liste bereits als
  # zutreffend bekannter Playlist-Ids und synchronisiert die TrackTag-Zeilen entsprechend.
  # Gemeinsam genutzt von Alias-basierten Tags und den dynamisch erzeugten Datums-Tags, da beide
  # ab dem Punkt "diese Playlists gehoeren zu diesem Tag" identisch weiterverarbeitet werden.
  sync_tag = lambda do |tag, matching_playlist_ids|
    counts = PlaylistTrack.where(playlist_id: matching_playlist_ids).group(:track_id).count

    stale_track_ids = tag.track_tags.pluck(:track_id) - counts.keys
    if stale_track_ids.any?
      tag.track_tags.where(track_id: stale_track_ids).delete_all
      total_removed += stale_track_ids.size
    end

    counts.each do |track_id, count|
      track_tag = tag.track_tags.find_or_initialize_by(track_id: track_id)
      new_strength = strength_for_count.call(count)
      next if track_tag.persisted? && track_tag.strength == new_strength

      track_tag.strength = new_strength
      track_tag.save!
      total_upserted += 1
    end
  end

  playlists_raw = Playlist.pluck(:id, :name)
  playlists = playlists_raw.map { |id, name| [id, Tag.normalize(name)] }
  # "Auftrittsdatum"-Tags werden weiter unten per Regex direkt zugeordnet, nicht ueber
  # Alias-Matching - sonst wuerde z.B. ein kurzes Jahres-Tag ("2026") faelschlich auch in
  # praeziseren Daten ("2026-01-05...") mitmatchen (siehe Kommentar oben).
  tags = Tag.includes(:category).to_a.reject { |tag| tag.category.name == "Auftrittsdatum" }

  puts "#{tags.size} Tags, #{playlists.size} Playlists"

  ActiveRecord::Base.transaction do
    tags.each do |tag|
      # Anzahl matchender Playlists pro Track = Rohbasis fuer die Staerke. Eine Playlist ohne
      # Alias-Treffer (z.B. ein reiner Datums-Praefix "2021-02-Fusion") liefert schlicht keinen
      # Eintrag hier - es wird nie ein Tag erzwungen, wenn kein Alias matcht.
      matching_playlist_ids = playlists.select { |_id, normalized_name| tag.matches_normalized_name?(normalized_name) }
                                        .map(&:first)
      sync_tag.call(tag, matching_playlist_ids)
    end

    # find_or_create_by! statt find_by! - die Migration AddAuftrittsdatumCategory legt die
    # Kategorie zwar bereits an, aber der Task soll auch dann funktionieren, wenn er (z.B. in
    # Tests, die die Test-DB nur aus dem Schema statt aus Migrations-Daten aufbauen) vor dieser
    # Migration ausgefuehrt wird.
    date_category = Category.find_or_create_by!(name: "Auftrittsdatum") { |c| c.is_event = true }
    playlist_ids_by_date = Hash.new { |h, k| h[k] = [] }
    playlists_raw.each do |id, name|
      date_string = extract_performance_date.call(name)
      playlist_ids_by_date[date_string] << id if date_string
    end

    puts "#{playlist_ids_by_date.size} Auftrittsdaten erkannt"

    playlist_ids_by_date.each_key do |date_string|
      date_category.tags.find_or_create_by!(name: date_string) { |t| t.aliases = date_string }
    end

    # Alle bestehenden Datums-Tags werden erneut synchronisiert (nicht nur die aktuell
    # erkannten) - so verlieren zuvor erkannte Daten, die inzwischen zu keiner Playlist mehr
    # gehoeren (umbenannt/geloescht), korrekt wieder ihre TrackTags statt fuer immer stehen zu
    # bleiben. Der Hash liefert dank Default-Proc [] fuer nicht mehr vorkommende Daten.
    date_category.tags.reload.each do |tag|
      sync_tag.call(tag, playlist_ids_by_date[tag.name])
    end
  end

  puts "Fertig. #{total_upserted} TrackTags neu/aktualisiert, #{total_removed} veraltete entfernt."
end
