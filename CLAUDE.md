# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

At the start of every session, read `AGENTS.md` and `CODE_GUIDELINES.md` in full before making any changes.

## What this is

Musicnet is a Rails app for a single Spotify user (the DJ) to:
1. Fetch their Spotify playlists (filtered to those with "fusion" or "blues" in the name) and mirror them into a local DB (playlists, tracks, albums, artists).
2. Download the actual audio files for those tracks via the external `spotdl` CLI tool.
3. Generate `.m3u` crate playlists for the Mixxx DJ software from the downloaded files.

Comments and commit messages in this codebase are largely in German (Swiss context).

## Commands

```bash
bin/setup                        # bundle install, db:prepare, clear logs/tmp, restart
bin/rails server -p 3001          # must run on 127.0.0.1:3001 — Spotify OAuth callback is registered against
                                  # that exact loopback address/port (see doc/diary.md, 2025-12-04 entry)
bin/rails console
bundle exec rspec                # run test suite (spec/)
bundle exec rspec spec/models/user_spec.rb        # single file
bundle exec rspec spec/models/user_spec.rb:12     # single example by line
bundle exec rubocop              # lint

# Rake task: build .m3u crate files for Mixxx from downloaded tracks
bin/rails create_crates_lists     # writes to /Users/chrigu/Documents/mixxx/<playlist-name>.m3u (hardcoded path)
```

There is no `config/database.yml.sample` checked in — sqlite3 is the DB, standard `bin/rails db:prepare` sets it up.

Spotify credentials (`client_id`/`client_secret`) live in Rails encrypted credentials, not env vars:
`Rails.application.credentials.dig(:spotify, :client_id)`. They're read at boot in
`config/application.rb#authenticate_to_spotify` (to authenticate the whole app against the Spotify Web API)
and again in `config/initializers/devise.rb` (to configure the omniauth `:spotify` strategy for user login).
Edit with `EDITOR="vi" bin/rails credentials:edit` (and `--environment development` for dev-specific creds).
Never commit `config/master.key`.

## Architecture

### Data model

Two independent representations of "the same" Spotify data coexist and it's important not to confuse them:
- **`RSpotify::*` objects** (`RSpotify::User`, `RSpotify::Track`, etc.) — live objects fetched directly from the
  Spotify Web API via the `rspotify` gem. Used transiently, e.g. in `TracksController#recently_played_index`.
- **Local ActiveRecord models** (`Track`, `Playlist`, `Album`, `Artist`) — a persisted mirror, populated by
  `BuildMusicNetService`. These are what the rest of the app (crate export, download services) operates on.

Local schema relationships:

```
playlists <-->> playlist_tracks <<--> tracks <<---> albums
                                       ^
                                       |
                                 artists_tracks (join table)
                                       |
                                     artists
users (separate: local login identity + holds serialized RSpotify::User via User#spotify_user)
```

- `Track#track_path`: there is no `file_path` column. The path to a downloaded audio file is derived at
  runtime by matching the sanitized track name against the files in `downloads/tracks/` (pattern
  `*-?<sanitized-track-name>.m4a` — the download tool `spotdl` names files that way; matching is
  case-insensitive, skips dotfiles, and treats backslashes in track names as escapes, replicating the
  `Dir.glob` semantics it replaced). If a track hasn't been downloaded, or the sanitization doesn't match
  spotdl's actual filename, this returns nil silently (logged, not raised). The result (including nil) is
  memoized per instance. **Any view/loop that touches `track_path` or `genre` for many tracks must call
  `Track.preload_track_paths(tracks)` first** — one directory scan for the whole batch instead of one per
  track; `tracks#index/#download`, `playlists#show/#refresh` and `artists#show` do this.
- `Track#genre`: read-through cache. Reads the `genre` DB column first; if empty, parses the downloaded
  file's metadata (WahWah) and persists a present value via `update_column`. Invalidation is manual:
  `Track.update_all(genre: nil)` in the console after re-downloads/re-tagging (see Intent 28).
- `Track#af`/`#energy`/`#tempo`: `audio_features` is a JSON blob column, wrapped lazily into an `OpenStruct`.
  Populated locally via Essentia (`AudioFeaturesExtractor`/`AudioFeaturesExtractionService`, Intent 35) right
  after a track's file is downloaded — not by Spotify: its `audio-features` endpoint has been permanently
  locked for apps without Extended Quota Mode access since November 2024 (a personal single-user app like
  this one cannot qualify). `AudioFeaturesExtractor` runs the `ghcr.io/mgoltzsche/essentia` **Docker image**
  (Docker must be installed and running; not a gem/bundled dependency, same "external tool" pattern as
  `spotdl`) via `Open3.capture2`, mounting the track's directory read-only and invoking
  `essentia_streaming_extractor_music` with `-` as the output path so the result comes back as JSON on
  stdout. The Homebrew tap (`MTG/essentia`) was tried first but doesn't reliably compile on Apple Silicon
  (known open upstream issues) — Docker's multi-arch image sidesteps that. Parses `rhythm.bpm` /
  `lowlevel.average_loudness` and stores `{"tempo" => ..., "energy" => ...}` via `update_column` — no
  callbacks, same cache semantics as `#genre`. Failure (command fails, output unreadable, neither value
  present) is logged and leaves `audio_features` nil, same soft-failure style as the rest of the app.
  `rake extract_missing_audio_features` backfills tracks that were
  downloaded before this existed.
- `User#spotify_user`: reconstructs an `RSpotify::User` from the `spotify_user_data` JSON column captured at
  OAuth login time (`UsersController#spotify`). This is how the app acts as "the logged-in Spotify user" for
  API calls elsewhere (e.g. `BuildMusicNetService`, recently-played).

### Sync flow (`BuildMusicNetService`)

Entry point: `PlaylistsController#fetch_all` → `BuildMusicNetService.new(current_user).build`.

1. Fetches all of the current user's own Spotify playlists (paginated), filters to those whose name contains
   the keyword of at least one configured `Library` (`SpotifyPlaylistsGateway#owned_library_playlist?`, Intent
   57 — replaced a fixed, hardcoded `/fusion|blues/i` regex). This import filter is driven by `Library` records
   the user manages themselves (see "Bibliotheken (Libraries)" below) — do not confuse it with that same
   section's *display* filter, which affects only what's shown, never what's imported, even though both key
   off the same `Library#keyword` values.
2. Per playlist, compares the local `snapshot_id` with Spotify's (Spotify changes it on every playlist
   modification; delivered with the playlist list, no extra API call):
   - not present locally → created with all its tracks (`build_playlist`; `find_or_create_by!` for
     `Track`/`Album`/`Artist`(s) plus a `PlaylistTrack` join row).
   - `snapshot_id` unchanged → **skipped entirely** (no tracks fetch, no DB writes) — this is what keeps a
     typical sync at seconds instead of minutes (Intent 31; before: 95s for 234 playlists).
   - `snapshot_id` changed → reconciled via `sync_playlist_with_spotify` (shared with `refresh_playlist`):
     vanished tracks unlinked, new ones created, name + `snapshot_id` updated.
3. Local playlists whose `spotify_id` is no longer in the Spotify list are destroyed
   (`delete_vanished_playlists`; `PlaylistTrack` rows go with them via `dependent: :destroy`), then any
   `Track`/`Artist`/`Album` left with zero associations is pruned (orphan cleanup).

Before creating records, both `build_playlist` and `sync_playlist_with_spotify` call `prefetch_details` (Intent
33), which fetches Spotify details for locally-new tracks in batches instead of one request per record: full
albums and full artists via `SpotifyPlaylistsGateway#albums_by_id` / `#artists_by_id` (20/50 ids per request
respectively). Only albums/artists not yet in the local DB are looked up. This is what keeps a from-empty-DB
first import in the minutes range instead of 30–60+ minutes for a few thousand tracks (before: one serial
request per new album/artist). A failed batch call is logged and its slice is simply missing from the result
— the affected fields stay `nil` and the import continues, same soft-failure semantics as the old per-record
`try_fetch`; a 429 (rate limit) is instead retried with backoff (`SpotifyPlaylistsGateway#fetch_in_slices`)
since a full sync across many playlists otherwise exhausts Spotify's rate limit on almost every batch. Track
audio features (tempo/energy) are no longer part of this prefetch — see `Track#af` above (Intent 35).
4. Returns a `ServiceInfo` object (created/deleted names per type) that the view renders as a sync summary.

`PlaylistsController#refresh` (single-playlist "Playlist aktualisieren" button) always calls `refresh_playlist`
→ `sync_playlist_with_spotify` in full, skipping the snapshot-unchanged fast path above (it's an explicit,
one-off user action, not the bulk sync) — this also means `updated_at` is a reliable "last synced" timestamp
for a single playlist (shown on `playlists#show`), since it's touched on every explicit refresh regardless of
whether anything actually changed, and on the bulk path only when `sync_playlist_with_spotify`/`build_playlist`
actually run. On success `refresh` **redirects** to `playlist_path` with the `RefreshInfo` (added/removed track
names) passed via `flash[:refresh_added]`/`flash[:refresh_removed]`, rendered as an alert on the next page load
— it does not `render :show` directly. Every action with side effects (`download`, `refresh`, `fetch_all`) is
routed as `POST` and must redirect rather than render inline: Turbo 8 prefetches plain `GET` links on hover
(Intent 34), and a direct 200 render after a `POST`/`data-turbo-method` submission is a Turbo/Rails
anti-pattern that can silently fail to show feedback (Intent 37) — redirect-after-mutation sidesteps both.

`find_or_create_by!` still means fields of already-existing rows are not updated when records are (re)created;
renamed playlists **are** updated (step 2, changed snapshot), renamed tracks are not — a renamed track only
corrects itself once the old row is orphaned and recreated.

### Bibliotheken (Libraries) — configurable import/display filter (Intent 57, replaces Intent 54)

The DJ has many Spotify playlists beyond just Fusion/Blues and wanted both the sync-time import filter and the
display-time category filter to be user-configurable and open-ended, instead of two hardcoded categories baked
into the code. `Library` (`name`, `keyword`) is the single model behind both: `Library.matching(playlist_name)`
(the *only* place that does the case-insensitive keyword-in-name substring check) returns every `Library` whose
`keyword` appears in a given playlist name — used both to decide what gets imported and which library(ies) a
playlist belongs to. A playlist can belong to **multiple** libraries at once (`Playlist has_many :libraries,
through: :library_playlists`, a real m:n join, not the single-select enum Intent 54 used) — e.g. a playlist
named "Blues Fusion Night" matching both a "Blues" and a "Fusion" library's keyword.

**Import filter:** `SpotifyPlaylistsGateway#owned_library_playlist?` = owned by the current user AND
`Library.matching(playlist.name).any?` — replaces the old hardcoded `/fusion|blues/i` regex, now fully driven
by whatever `Library` rows exist.

**Automatic assignment during sync:** `BuildMusicNetService#assign_libraries(playlist)` sets
`playlist.library_ids = Library.matching(playlist.name).map(&:id)` — Rails' `collection_ids=` diffs the m:n
rows automatically (adds new, removes stale). Called at the end of both `build_playlist` (newly-imported
playlist) and `sync_playlist_with_spotify` (so a rename on Spotify recomputes the assignment, same spot that
already updates `name`/`snapshot_id`).

**Bibliotheken-Verwaltung (`LibrariesController`, `resources :libraries, except: [:show]`):** plain CRUD
(name + keyword) with a "Bibliotheken" navbar entry. Deleting a `Library` nullifies any `User#active_library_id`
pointing at it (`Library has_many :users, foreign_key: :active_library_id, dependent: :nullify`) so "Alle"
(nil) is always a safe fallback state, never a dangling foreign key.

**Retroactive resync (manually discovered gap, fixed same intent):** the mechanisms above only ever fire during
a Spotify sync (new import or a rename-triggered re-sync) — creating or editing a `Library` through the admin
UI had **zero** effect on playlists already sitting in the local DB, since nothing about editing a `Library`
itself triggers a sync. Confirmed the hard way: creating a "Salsadancers" library with keyword "salsa" showed
zero matching playlists/tracks despite several already-imported "...Salsa..." playlists existing locally.
Fixed by having `LibrariesController#create`/`#update` call `Library#resync_playlist_assignments!` right after
a successful save — iterates every local `Playlist` and adds/removes *this one* library's join row depending
on whether its keyword currently matches the name, using the same match predicate as everywhere else. Note this
only fires on an actual create/edit of the `Library` record; merely selecting an already-existing, already-fully-
synced library as the active display filter in Settings never needed this (nothing about its assignments would
be stale in that case).

**Display filter:** `User#active_library` (`belongs_to :active_library, class_name: "Library", optional: true`
— nil means "Alle", no filter; replaces Intent 54's `active_playlist_category` string enum +
`active_category_substring`). Three model scopes, all `in_active_library(library_id)`, blank/nil id → unchanged
relation:
- `Playlist.in_active_library` — subquery `where(id: joins(:libraries).where(libraries: { id: library_id
  }).select(:id))`.
- `Track.in_active_library` / `Artist.in_active_library` — same subquery-over-`where(id: ...)` pattern as
  `Track.by_artist`/`by_playlist` (Intent 43): `Track` joins `playlists: :libraries`, `Artist` joins
  `tracks: { playlists: :libraries }` (an artist counts as "in library X" if *any* of their tracks sits in a
  playlist belonging to that library). The subquery shape matters here for the same reason it did in Intent 43
  — it composes safely with whatever other joins/conditions the base relation already carries (search, sorting,
  preloads) instead of risking a join-fanout or an alias collision. The m:n join's unique index on
  `[library_id, playlist_id]` means filtering by one specific `library_id` can never fan out into duplicate
  rows here, even though the underlying relationship is m:n.

Wired into `TracksController#index` (chained *after* `search_query`, so the DSL search — including an internal
`OR` producing a unioned relation — still gets AND-ed with the library filter correctly), `PlaylistsController
#index` (also `.includes(:libraries)` there and in `Track.for_show`, since `playlists/_playlist.erb` — reused
by both `playlists#index` and `tracks#show`'s "Playlists die diesen Track enthalten" table — renders
`playlist.libraries.map(&:name)` and both call sites are `strict_loading`), `ArtistsController#index`, and
`TrackQuerySuggestions` (Intent 55, playlist-/artist-/genre-suggestions). Changed via `SettingsController`
(`resource :settings, only: %i[edit update]`, radio buttons built dynamically from `Library.order(:name)` plus
a fixed "Alle" option, navbar "Einstellungen" link) — deliberately a full settings page rather than a navbar
quick-toggle dropdown, since switching library isn't expected to happen many times per session. `playlists
#index`/`#show` also list each playlist's library names directly (read-only — assignment is always automatic,
never edited from the playlist side).

### Download flow

Both download services shell out to the external `spotdl` Python CLI (must be installed and on PATH; not a
gem/bundled dependency) via `system(...)`, always after `Dir.chdir`-ing into `downloads/tracks`:

- `DownloadPlaylistService` (`playlists#download`) — command built by `DownloadPlaylistCommandBuilder`, which
  branches on `Playlist#missing_tracks` (tracks without a local file, see `Track#track_path`):
  - **1–10 missing tracks** (`SMALL_BATCH_THRESHOLD`): `spotdl download <track_url> <track_url> ...` for just
    those tracks — no `--user-auth` (Spotify track metadata is always public, unlike playlists) and no
    `--sync-without-deleting` (no deletion reconciliation needed for an explicit, targeted download).
  - **0 or >10 missing tracks**: falls back to the previous `spotdl sync <playlist_url> --save-file
    <name>.spotdl --sync-without-deleting [--user-auth] --format m4a`. Individual track URLs each cost spotdl
    their own separate Spotify API calls (track/album/artist), while a playlist sync fetches everything
    bundled in one request — with ~37 individual track URLs at once this caused a 24h rate-limit ban in 2024
    (Intent 21), hence the threshold; `DownloadMissingTracksJob` below is deliberately **not** switched to
    per-track URLs for the same reason.
  Both branches also pass `--save-errors <file>`. After a successful run, `DownloadResultParser` decides
  success per track from **`Track#track_path` re-checked fresh after the run** (`Track.preload_track_paths`),
  not from the `--save-file` JSON's `download_url` — that field is `null` both for a genuine failure *and*
  when spotdl skips a track because the file already exists (e.g. downloaded in an earlier run), and the JSON
  gives no way to tell those apart. `download_url`, when present, is only used to name the provider (its host,
  e.g. `youtube.com` → "YouTube"); a track with a file but no `download_url` shows as downloaded with provider
  "unbekannt". The `--save-file` JSON itself comes in two shapes depending on operation — `spotdl sync` writes
  `{"songs": [...]}`, `spotdl download` (small-batch) writes a bare array, `song_id` matches `Track#spotify_id`
  either way. The `--save-errors` text is matched to a track name best-effort for the failure reason. Temp
  files (`--save-errors` always; `--save-file` only for the small-batch branch, since the sync branch's
  save-file is the playlist's persistent state) are deleted after parsing. It also calls
  `AudioFeaturesExtractionService.new(@playlist.tracks).extract_missing` (Intent 35), so newly-downloaded
  tracks get their Essentia-based audio features right away.
  The result is rendered via `flash[:download_added]`/`flash[:download_failed]` on `playlists#show` (Intent
  38, same redirect+flash pattern as `refresh` below) — since flash lives in the client-side session cookie
  (~4KB limit, and encryption+Base64 cost roughly 1.5–2× the raw payload size in practice), both lists are
  capped at `PlaylistsController::MAX_FLASH_ENTRIES` (8, with a "+N more" note and a `..._total` count) and
  each entry's name/reason is truncated (`DownloadResultParser::MAX_NAME_LENGTH`/`MAX_REASON_LENGTH`) — a real
  `CookieOverflow` 500 was hit in testing with a 178-track playlist before this was added.
- `DownloadMissingTracksJob` (`tracks#download`, Intent 39) — runs in the background (`ActiveJob`, the
  built-in `:async` in-process adapter; no Sidekiq/Solid Queue/Redis needed for this single-user local app)
  instead of blocking the request: with many affected playlists the old synchronous
  `DownloadTrackService` could take hours (one playlist sync alone took ~27 min in testing due to Spotify
  rate limits) with the browser tab hanging and zero feedback. The job delegates to `DownloadPlaylistService`
  per affected playlist (so the audio-features extraction above applies here too) rather than invoking
  `spotdl` directly, and after each playlist finishes broadcasts a Turbo Stream
  (`Turbo::StreamsChannel.broadcast_append_to("downloads", ...)`) with that playlist's result (from
  `DownloadResultParser`, Intent 38); a final broadcast marks completion. `TracksController#download` checks
  `DownloadPlaylistService::DOWNLOAD_LOCK.locked?` **before** enqueueing and shows an alert instead of
  starting a second job, since a lock error inside an already-running background job can no longer be
  rescued synchronously in the controller. `/tracks` subscribes via `turbo_stream_from "downloads"` and an
  empty `#download-log` container placed **outside** `turbo_frame_tag "tracks"` — inside it, a search/sort/
  page change would replace the frame's content and wipe the accumulated live log.

### Tracks index (`TracksController#index`, Intent 34)

`/tracks` is paginated (Pagy, `TracksController::PAGE_SIZE = 50`), sortable and searchable via
query params, all wrapped in a `turbo_frame_tag "tracks"` so sorting/searching/filtering/paging
update only the table, not the whole page (navbar included) — this needs no controller code:
`turbo-rails` auto-includes `Turbo::Frames::FrameRequest` in `ActionController::Base`, which
swaps in a minimal layout whenever a request carries a `Turbo-Frame` header. The frame carries
`data: { turbo_action: "advance" }` (Intent 50) so these frame-only navigations also push the
browser URL/history, same as a normal page visit — without it, Turbo updates the frame silently
and the address bar always stayed at plain `/tracks`, losing the search/sort/page state on leave
and return, back/forward, or a shared link. Verified only via Cuprite system specs (pure browser
behavior, invisible to request specs): URL sync, back-button restoration, and — since the
persistent audio player and the live download-log (Intent 39/40, both deliberately outside this
frame) are unaffected by construction (still only the frame's own content is ever replaced) —
that a track keeps playing uninterrupted (same DOM node) across a search. Accepted side effect:
page scroll now resets to top on every action (advance is handled like a real visit, including
scroll reset) where it previously stayed put — negligible for search/sort (controls sit at the
top already) and only noticeable when paginating (links sit below the table).

**Shared sort headers (`tracks/_tracks.erb`, `TracksHelper#sort_link`, bug fix Intent 63):**
`sort_link` links via `url_for(query)`, not a hardcoded `tracks_path(query)` — this partial is
also rendered by `artists#show` (`Artist.for_show(@artist).sorted(...)`, same `Track.sorted`/
`SORT_COLUMNS` whitelist as here), and `url_for` in a view fills in whatever's missing from the
given Hash (controller/action, path params like an artist's `:id`) from the current request, so a
click stays on whichever page rendered it — `/tracks` stays `/tracks`, `/artists/:id` stays
`/artists/:id` — without `sort_link` needing to know which page it's on. Before this fix, a sort
click from `artists#show` always navigated away to `/tracks` and, since `artists#show` didn't
apply `sort`/`direction` at all, wouldn't even have sorted anything if it had stayed.

Query params:
- `q` — a small DSL (`Track.search_query`, Intent 43), not just plain full-text. Tokens are
  whitespace-separated; a bare word (no `field:`) is free text, matched exactly like the old
  `Track.search` (still used internally for the free-text portion) — case-insensitive substring
  over name/artist/album/genre/playlist name, `LEFT JOIN` + `distinct` so a track with several
  artists/playlists doesn't appear twice. A `field:value` token filters one attribute instead:
  `artist:`, `album:`, `genre:`, `playlist:` (substring match), `bpm`/`tempo:`, `energy:`,
  `popularity:`, `year`/`release:` (numeric/date, support `min..max` ranges and `>`/`>=`/`<`/`<=`
  comparisons). A comma-separated value (`genre:jazz,fusion`) is OR'd; a `-` prefix
  (`-genre:blues`) negates the token; quote a value with spaces (`playlist:"Fusion Abende"`).
  Repeating the same field as separate tokens (`playlist:A playlist:B`) is AND — each token is
  applied as its own `where(id: <field-scope>.select(:id))` subquery rather than a direct
  `joins(...).where(...)` on the main relation, specifically so two tokens for the same m:n
  association (`by_artist`/`by_playlist`) each get their own independent join instead of both
  constraining the same joined row (which could never satisfy two different values at once).
  Single-valued fields (`by_genre`/`by_album`/the numeric fields) don't strictly need this, but
  use the same subquery shape for consistency. `TrackQueryParser` (tokenizing + classifying a
  value as list/range/comparison/plain) and the per-field `Track.by_*` scopes are deliberately
  hand-rolled rather than a gem (`search_cop`'s fulltext-index features target MySQL/Postgres, not
  documented against SQLite; `scoped_search` has been unmaintained since 2017) — consistent with
  the existing whitelist-based raw-SQL style already used for `SORT_COLUMNS`. An unknown field
  name falls back to being treated as a free-text term (e.g. `composer:Bach` — there is no
  `composer` field/data source at all); an invalid value for a known numeric field (`bpm:abc`) is
  silently ignored — same soft-failure philosophy as the rest of this app, never an error. Blank
  query returns the relation unchanged (no join overhead).
  `TracksController#query_suggestions` (`GET /tracks/query_suggestions?term=...`,
  `TrackQuerySuggestions`) backs a small autocomplete: given the last token being typed, it
  suggests matching field names (no `:` yet) or matching DB values for text fields (genre/artist/
  album/playlist substring match, quoted if the value contains a space) — wired up via the
  `search-suggestions` Stimulus controller (debounced fetch, dropdown, click inserts the
  suggestion). Suggestions only match against the last comma-separated segment being typed
  (earlier segments are kept as a literal prefix) and strip a leading, not-yet-closed `"` before
  matching (Intent 49) — otherwise both a second comma-list value and a just-opened quote would
  get zero suggestions, since the whole remainder would be used as one literal LIKE fragment.
  Verified with a Cuprite system spec (`spec/system/track_search_autocomplete_spec.rb`), same
  rationale as Intent 40: this interaction is only observable in a real browser.
  Two operators beyond plain field:value/comma/negation: `OR` (uppercase only — a lowercase `or`,
  or `OR` inside quotes, stays literal) joins two criteria groups with lower precedence than the
  implicit whitespace-AND, mirroring Mixxx's search syntax (Intent 47) — `TrackQueryParser` tags
  it as its own token type, `Track.search_query` splits the token stream into AND-groups at each
  `:or` token, evaluates each group with the existing logic, then wraps every group's result as
  `where(id: group.select(:id))` before combining with `Relation#or` (wrapping first is required:
  `Relation#or` needs structurally identical relations, but one group having free text — which
  pulls in `Track.search`'s own `left_joins`/`distinct` — and another not would otherwise differ).
  Separately, `field: value` (space after the colon) is tolerated for a single word or a quoted
  phrase, but only for a field in `Track::FIELD_SCOPES` — `TrackQueryParser#tokenize` merges a
  dangling `field:`-shaped raw token with the following one only when the field name is in the
  `known_fields:` list passed by `Track.search_query`, so an incidental colon in ordinary free
  text (e.g. a track named "Blues: The Story") is never mistaken for a field (Intent 48). An
  unquoted, multi-word value after the space (`artist: James Cotton`) is still ambiguous and
  remains unsupported — documented as a known limitation in `doc/track_search_syntax.md` rather
  than solved, since there's no unambiguous rule for where such a value would end.
- `sort`/`direction` — `Track.sorted`, driven by the `Track::SORT_COLUMNS` whitelist (never raw
  param into `order()`); unknown column/direction silently falls back to the default (`name`,
  `asc`). `energy`/`tempo` sort via `json_extract(tracks.audio_features, '$.energy'/'$.tempo')`
  since they live in the `audio_features` JSON blob, not their own column.

There is no `available`/file-availability filter (removed in Intent 45) — it added a second,
Ruby-array-based pagination path alongside the normal SQL one for comparatively little value.

### Help articles

`doc/*.md` files can double as in-app help articles: `HelpController#show` (`GET /help/:page`,
route name `help`) looks `params[:page]` up in the `ARTICLES` whitelist constant (slug → title +
filename under `doc/`) and renders the matching file at request time via
`Redcarpet::Markdown.new(Redcarpet::Render::HTML)` — an unknown slug renders a plain 404 rather
than raising. Each Markdown file is the single source, never duplicated into a separate view
(Intent 46). Originally a single, hardcoded `#search_syntax` action/route (Intent 46); generalized
into this whitelist-driven `#show` (Intent 52) when three more articles were added: `suche-syntax`
→ `doc/track_search_syntax.md` (documents the DSL search syntax, including the `OR` operator and
where a space after `field:` is/isn't tolerated, Intent 43/45/47/48), `installation` →
`doc/installation.md` (setup on a new machine — credentials, external tools), `bedienung` →
`doc/usage.md` (day-to-day workflow: playlists, search, queue, cue channel, download, Mixxx
export), `diary` → the existing `doc/diary.md`. The README's own setup section was replaced by a
link to `doc/installation.md` rather than kept as a second, separately-maintained copy, the same
principle already applied to `doc/track_search_syntax.md`. The navbar's "Hilfe" item is a dropdown
rather than a flat link specifically so further help articles can be added as more entries later
(now populated with all four, `Intent 52`).

### Mixxx crate export

`lib/tasks/write_mixxx_files.rake` (`create_crates_lists`) writes one `.m3u` file per `Playlist` to a hardcoded
path (`/Users/chrigu/Documents/mixxx/`), listing the on-disk paths of its tracks (again via `Track#track_path`).
Per the README, the operator then manually clears Mixxx's existing crates (deleting rows in Mixxx's own
`mixxxdb.sqlite`, tables `crates`/`crate_tracks`) before importing the fresh `.m3u` files via Mixxx's UI.

### Auth

- Login is Devise + `omniauth-spotify` (OAuth against the user's own Spotify account) — see
  `config/initializers/devise.rb` for the requested scopes and `UsersController#spotify` for the callback.
  Requires the `omniauth-rails_csrf_protection` gem to work (without it, omniauth throws
  `OmniAuth::AuthenticityTokenProtection` — see README "Diary").

### Frontend

Server-rendered ERB views + Bootstrap 5 + Hotwire (Turbo/Stimulus via importmap-rails, no Node/yarn build step).

**Persistent audio player (Intent 40):** a single global mini-player lives in the shared layout
(`layouts/_audio_player.html.erb`, rendered once in `application.html.erb`), not per track row.
It's marked `data-turbo-permanent` with a stable `id="global-audio-player"` — Turbo Drive matches
elements by id between the old and new document on a full page visit and reuses the existing DOM
node (including in-progress playback) instead of replacing it; being outside
`turbo_frame_tag "tracks"` additionally means a search/sort/pagination frame update never touches
it at all. Per-track play buttons (`components/_audio_file.html.erb`) don't own an `<audio>`
element anymore — they carry a tiny `audio-trigger` Stimulus controller that only dispatches an
`audio-player:play` event (`{ url, name }`) on `document`; the single `audio-player` controller
instance on the persistent bar listens for that event and does the actual `src`/play switch. This
event-based decoupling avoids needing a direct reference (e.g. a Stimulus outlet) between
controllers that live in unrelated parts of the DOM. Row buttons originally always showed "▶"
regardless of playback state, to avoid needing to sync state across every row — reversed for the
main channel in Intent 62, see "Live row state" below (the cue channel already broke this rule
earlier, in Intent 51 Nachtrag).
**Seeking (`TracksController#stream`):** plain `send_file` only ever returns the full file
(`ActionDispatch::Response::FileBody`, no partial-content handling) unless a reverse proxy adds
`X-Sendfile`/`X-Accel-Redirect` support, which this single-user local app doesn't have — so
without extra work, dragging the player's progress slider had no effect: `<audio>` needs the
server to honor `Range` requests to fetch just the bytes around a new position, and a plain 200
response with the whole body doesn't satisfy that. `stream` now parses a single `Range` header via
`Rack::Utils.get_byte_ranges` and returns `206 Partial Content` with `Content-Range`/`Accept-Ranges`
when present, falling back to a normal full-file `send_file` otherwise (multi-range requests, which
browsers don't send for `<audio>`, also fall back to the full file rather than implementing
`multipart/byteranges`).
**System-spec / JS testing:** `capybara` + `cuprite` (`spec/support/capybara.rb`) — Cuprite drives
a real, separate headless Chrome via CDP directly (no Selenium/webdriver binaries). This is the
first and only place in the suite verifying real browser/Turbo/Stimulus behavior; everything else
is request/model/service specs. `login_as` works with the real-browser driver because Capybara
runs the Rails app in-process for system specs, sharing Warden's test-mode state. Shared helpers
(`create_playable_track`, `play_button_for`, `enqueue_button_for`, `cue_button_for`) live in
`spec/support/playback_test_helpers.rb`.

**Cue-/Vorhörkanal (Intent 51):** a second, independent `<audio>` channel for previewing a track
without interrupting the main player's queue playback — e.g. cueing up a candidate track through
headphones while the current track keeps playing to the room, like the cue/PFL channel on a real
DJ mixer. Lives as an extra compact row inside the same permanent `#global-audio-player` container
(no second `fixed-bottom` element, avoids overlap/extra `.page-content` padding math) with its own
`cue_player_controller.js`, which — like `audio_player_controller.js` — knows nothing about the
other controller; both only react to events dispatched by `audio_trigger_controller.js`
(`audio-player:play` vs. the new `audio-player:cue`) on the per-track "▶"/"🎧" buttons in
`components/_audio_file.html.erb`. The "🎧" button stays visible even for an already-queued track
(unlike "▶"/"+", replaced by an "in Queue" badge) since previewing is independent of queue state.
Output device routing uses `HTMLMediaElement.setSinkId()`. Getting a `deviceId` to pass to it took
a correction (Intent 51 follow-up): `navigator.mediaDevices.selectAudioOutput()` (a native
device-picker) looked like the right tool, but per MDN's browser-compat-data it's Firefox-only
(116+) — **not implemented in Chrome**, the opposite of this project's first assumption.
`setSinkId()` itself is the older, broadly-supported piece (Chrome since v49) — only the device
*picker* needed a different approach: `navigator.mediaDevices.enumerateDevices()` filtered to
`kind === "audiooutput"`, rendered into a plain `<select>`. Chrome only returns non-empty labels
for enumerated devices (audiooutput included, not just mic/camera input) once a `getUserMedia`
permission has been granted, so choosing a device briefly requests `{ audio: true }`, immediately
stops the resulting stream (the stream itself is never used, only its side-effect of unlocking
labels), then enumerates and populates the `<select>`. This is a real Chrome UX quirk, not a bug:
picking an output device prompts for microphone permission before the speaker list appears. This
whole flow (`loadOutputDevices`/`restoreOutputDevice`/`applyOutputDevice`) is shared code in
`app/javascript/audio_output_device.js` (pinned standalone in `importmap.rb`, since
`pin_all_from "app/javascript/controllers"` only covers the controllers directory and — more
importantly — that directory is eager-loaded by Stimulus as *all-controllers*, so a shared
non-controller helper can't live there without being wrongly registered as one) — both
`cue_player_controller.js` and `audio_player_controller.js` import it and each keep their own
`localStorage` key (`musicnet:cuePlayerSinkId` / `musicnet:mainPlayerSinkId`), so the two device
choices are independent. **The main player needed its own device picker too** (Intent 51
follow-up, reported after real-world use): with no explicit sink, it simply follows the OS's
current default output — connecting Bluetooth headphones commonly makes the OS switch its default
to them, which then silently drags the main/"dancefloor" channel onto the headphones right along
with the cue channel, defeating the whole point. Giving the main player the same explicit
picker/pinning lets it stay on the built-in speakers regardless of what the OS considers default.
Guarded by an `HTMLMediaElement.prototype.setSinkId` feature check that shows a message instead of
erroring where unsupported (e.g. Safari before 18.4).
**Testability limit:** the native permission-prompt and device-enumeration flow has no DOM and
can't be driven by Cuprite/Capybara (no real audio hardware in the headless test environment
either) — covered by a system spec only at the level of "both channels render their own,
independent device-picker controls" (`spec/system/cue_player_spec.rb`); actually granting the
permission, picking a device, and hearing it come out the right output remains a manual check.
**Layout note:** the "🎧" button pushed the per-row button count in the `.table-tracks-detailed`
"Datei" column from two to three; a real regression slipped through here once (the "+" button was
still in the DOM — Capybara could still find and click it — but visually clipped outside the
6%-wide fixed column, so no test caught it). Fixed by widening that column (`app/assets/
stylesheets/application.scss`) and adding `flex-wrap` to the row as a defensive measure against
this happening again with any future per-row button; `spec/system/
track_row_buttons_layout_spec.rb` now asserts every button's rendered bounding box stays within
the table's edge, specifically to catch this DOM-present-but-visually-clipped failure mode that
plain Capybara interaction specs don't.
**Live row state (Intent 51 Nachtrag):** the "🎧" button reflects whether *its own* track is the
one currently playing in the cue channel — red background + "⏸" while active, back to plain
outline + "🎧" otherwise — and clicking it while active toggles the cue channel off (pause)
instead of restarting the same track from the beginning. This is the one place a row button
mirrors live player state; `audio_trigger_controller.js`'s `mode` value (`"play"` default vs.
`"cue"`) gates it so the plain "▶" play button is untouched, per this file's own
"Row buttons always show '▶'" rule above — that rule was specifically about avoiding cross-row
state sync for the *main* player, not a blanket ban, and doesn't apply to the cue channel.
Implemented via the same document-level custom-event pattern as everywhere else in this player
stack: `cue_player_controller.js` broadcasts `cue-player:state` (`{ url, playing }`) on every
play/pause/track-change; every cue-mode trigger button compares that `url` against its own
(resolved to an absolute URL first, since `<audio>.src` always reads back absolute while the
button's own value is the relative `stream_track_path`) to decide whether it's the active one. The
bottom bar's own cue play/pause button (`data-cue-player-target="toggleButton"`) gets the same
red/outline toggle directly from `cue_player_controller.js`'s own play/pause listeners, so both the
row button and the persistent bar agree on which track is active.
**Cross-navigation sync (Nachtrag):** a freshly-loaded page's row buttons don't just wait
passively for the next `cue-player:state` broadcast — nothing re-broadcasts on navigation, since
the cue channel's own play/pause state hasn't changed, only the row markup around it has (freshly
rendered, not `data-turbo-permanent` like the cue player itself). So each cue-mode trigger button
also actively syncs its own initial appearance from the live `<audio>` element
(`document.querySelector('[data-cue-player-target="audio"]')`) — but only on the `turbo:load`
event, not directly in `connect()`: empirically (verified by hooking `Runtime.consoleAPICalled` via
Ferrum directly, since Cuprite's driver doesn't surface console logs by default), row buttons
`connect()` *before* Turbo has re-attached the permanent player element into the new document, so
a same-tick DOM read there intermittently finds nothing. `turbo:load` fires only once the whole
visit — permanent elements included — has actually settled, for both a first hard load and every
later Drive visit alike, so reading the live audio state there is race-free. An earlier attempt at
this used a request/response event pair (row asks, cue player answers) instead of a direct DOM
read; same race, since the request could equally be dispatched before the answering listener was
back in the live document — direct-DOM-read-on-`turbo:load` was the version that actually held up.

**Live row state for the main channel + fehlmanipulation guard (Intent 62):** the DJ asked to see
which track is playing on the main/dancefloor channel directly in the row list (not just the
persistent bar), plus protection against an accidental click stopping or replacing a live track.
Extends exactly the Intent 51 Nachtrag mechanism above to `audio_trigger_controller.js`'s `"play"`
mode (green `btn-success` + "⏸" instead of red `btn-danger` + "⏸", same `applyPlayState`/
`handlePlayState`/turbo:load-resync structure as the cue channel's `applyCueState`/`handleCueState`
— `audio_player_controller.js` gained its own `broadcastState()` on the same `play`/`pause`
listeners that already drove the bottom bar's icon, mirroring `cue_player_controller.js`'s existing
`broadcastState()`). Unlike the cue channel, clicking an already-active row button does **not**
just toggle — `audio-trigger#play` first does a live, uncached
`document.querySelector('[data-audio-player-target="audio"]')` read: if *this* row is the active
track, a native `confirm()` gates pausing it (accepting dispatches a new `audio-player:toggle`
event, which `audio_player_controller.js` wires straight to its existing `toggle()` — the same
method the bar's own Play/Pause button already calls); if the main channel is playing a *different*
track, `confirm()` gates switching to this one; if nothing is playing, it plays immediately with no
dialog. System specs drive the native dialog via Capybara's `accept_confirm`/`dismiss_confirm`
(supported out of the box by Cuprite). The persistent bar's own Play/Pause button mirrors this same
green state (`data-audio-player-target="toggleButton"` in `layouts/_audio_player.html.erb`, toggled
by the same `handleAudioPlay`/`handleAudioPause` listeners that already drove the bar's icon and
`broadcastState()`) — same DJ request extended to the one button that's always on screen regardless
of which row is visible, exactly mirroring the cue channel's bottom-bar button, which already turned
red under the same logic.

**Song queue (Intent 41, moved to the DB in Intent 42):** builds on the persistent player above.
Originally a pure client-side JS array on the permanent element (Intent 41) — moved to a real
`QueueEntry` model (`belongs_to :track`, ordered by `created_at`, capped at
`QueueEntry::MAX_SIZE`/5) once it became clear the DJ wants to (a) prepare a queue that survives a
real page reload, not just Turbo navigation, (b) see already-queued tracks marked in track listings
(needs server-side knowledge at render time — impossible with pure client JS state), and (c) save
the current queue as a reusable local playlist. The queue is now server-rendered
(`queue_entries/_queue_list.html.erb`, inside `#audio-player-queue-list` in
`layouts/_audio_player.html.erb`) and kept live via Turbo Streams — `QueueEntriesController#create`/
`#destroy` respond with `turbo_stream.update` re-rendering the list (simplest correct approach for
a 5-row-max table; no surgical prepend/remove needed), and `#advance` (called by the player's JS
when a track ends or the play button is pressed with nothing loaded) additionally broadcasts a
`broadcast_remove_to("queue", ...)` so any other open tab/page reflects the dequeue too. Because of
this, **`audio-trigger` and `audio-player` Stimulus controllers no longer manage the queue at
all** — the "+" button in `components/_audio_file.html.erb` is a plain `button_to` POST (Turbo
intercepts it and negotiates the `turbo_stream` format automatically, no custom JS), and the only
remaining JS/queue interaction is `audio_player_controller.js#playNextInQueue`, an async
`fetch("/queue_entries/advance", …)` that plays whatever track JSON comes back (204 = nothing
queued, silently do nothing) — note the CSRF meta tag is only present when
`allow_forgery_protection` is on, which Rails' test env disables by default, so the fetch reads it
via `?.content` rather than assuming it exists (`document.querySelector('meta[name="csrf-token"]')`
returns `null` in system specs otherwise, and `.content` on that throws, silently swallowing the
whole fetch). `ApplicationHelper#queued_track_ids` (`QueueEntry.pluck(:track_id)`, memoized per
request — the table is tiny so one query is enough) drives the "in Queue" badge on already-queued
rows; `components/_audio_file.html.erb` wraps its content in `dom_id(track, :audio_file)` so
`QueueEntriesController#broadcast_badge_update` can `broadcast_replace_to("queue", target: ...,
partial: "components/audio_file", ...)` and update that badge live too, on every page currently
showing that track — first shipped as a reload-only badge, then made live after the DJ pointed out
having to reload to see it (and to see it disappear again) defeated the point. The badge also
*replaces* the play/"+" buttons entirely for an already-queued track rather than sitting next to
them (deliberate: saves space, and a queued track doesn't need re-queuing). The queue widget itself
renders nothing at all — no placeholder text, no "save as playlist" form — while the queue is
empty (`queue_entries/_queue_list.html.erb` returns blank rather than "Queue leer"), so it doesn't
take any vertical space when there's nothing to show; `.page-content` in `application.scss` still
reserves a fixed 16rem of bottom padding site-wide sized for the *full* 5-entries-plus-form case
(measured ~210px), since the fixed-bottom bar would otherwise cover page content like pagination
controls whenever the queue is non-empty.
`QueueEntriesController#save_as_playlist` creates a plain local `Playlist.create!(spotify_id: nil)`
+ `PlaylistTrack` per queued track in order, and does *not* clear the queue afterward (accepted
design: saving is a snapshot, not a "finish and reset" action) — `spotify_id: nil` is safe against
`BuildMusicNetService#delete_vanished_playlists`'s `Playlist.where.not(spotify_id: [...])`, since
SQL's `NOT IN` semantics exclude `NULL` rows from matching (verified directly against the dev DB
before relying on it). Uploading the saved playlist back to Spotify itself is out of scope — the
app has never had Spotify *write* access, only reads.

Each queue entry also shows artist + playlist names under the title, via
`TracksHelper#artist_names_for`/`#playlist_names_for` — the latter reads `track.playlist_tracks` if
already preloaded (e.g. `/tracks`) or falls back to `track.playlists` (e.g. `tracks#show`), since
only one of the two is preloaded depending on caller and the other would raise under
`strict_loading`.

**ActionCable in test env uses `async`, not `test` (`config/cable.yml`):** the default `test`
adapter never actually delivers broadcasts over a real WebSocket, which silently breaks any system
spec (Cuprite, a real browser) that depends on a live Turbo Stream update (like the queue's
`advance` broadcast above) — nothing in the suite relies on the `test` adapter's introspection
matchers (the one broadcast-related job spec stubs `Turbo::StreamsChannel` directly), so switching
was safe project-wide.
