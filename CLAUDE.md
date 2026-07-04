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
   "fusion" or "blues" (`SpotifyPlaylistsGateway#all`).
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
swaps in a minimal layout whenever a request carries a `Turbo-Frame` header.

Query params:
- `q` — full-text search (`Track.search`), case-insensitive over name/artist/album/genre/
  playlist name, `LEFT JOIN` + `distinct` (a track with several artists or in several playlists
  must not appear twice). Blank query returns the relation unchanged (no join overhead).
- `sort`/`direction` — `Track.sorted`, driven by the `Track::SORT_COLUMNS` whitelist (never raw
  param into `order()`); unknown column/direction silently falls back to the default (`name`,
  `asc`). `energy`/`tempo` sort via `json_extract(tracks.audio_features, '$.energy'/'$.tempo')`
  since they live in the `audio_features` JSON blob, not their own column.
- `available` (`downloaded`/`missing`, whitelisted via `TracksController::AVAILABLE_FILTERS`) —
  whether a track's file exists on disk is deliberately **not** a DB column (see `Track#track_path`
  above), so this filter can't be pushed into SQL/Pagy's normal offset pagination. Instead,
  `TracksController#filter_by_availability` loads the already searched/sorted relation as an
  `Array`, does one `Track.preload_track_paths` scan for all matches, filters in Ruby, and hands
  the resulting `Array` to `pagy(:offset, ...)` — no special "array adapter" needed, the
  installed Pagy version (43.x) already paginates plain Arrays the same way as
  `ActiveRecord::Relation` (`Pagy::OffsetPaginator#paginate` slices `collection[offset, limit]`
  when `collection.instance_of?(Array)`). Without this filter, pagination stays on the normal,
  cheaper SQL path.

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
controllers that live in unrelated parts of the DOM. Row buttons always show "▶" — play/pause
state is only ever shown in the global bar, avoiding needing to sync state across every row.
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
(`create_playable_track`, `play_button_for`, `enqueue_button_for`) live in
`spec/support/playback_test_helpers.rb`.

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
