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

- `Track#track_path` / `#genre`: there is no `file_path` column. The path to a downloaded audio file is derived
  at runtime by globbing `downloads/tracks/*-?<sanitized-track-name>.m4a` — the download tool (`spotdl`) names
  files that way. If a track hasn't been downloaded, or the sanitization doesn't match spotdl's actual filename,
  this returns nil silently (logged, not raised).
- `Track#af`/`#energy`/`#tempo`: `audio_features` is a JSON blob column from Spotify's Audio Features API,
  parsed lazily into an `OpenStruct`.
- `User#spotify_user`: reconstructs an `RSpotify::User` from the `spotify_user_data` JSON column captured at
  OAuth login time (`UsersController#spotify`). This is how the app acts as "the logged-in Spotify user" for
  API calls elsewhere (e.g. `BuildMusicNetService`, recently-played).

### Sync flow (`BuildMusicNetService`)

Entry point: `PlaylistsController#fetch_all` → `BuildMusicNetService.new(current_user).build`.

1. Deletes all `PlaylistTrack` join rows (but not Track/Album/Artist — those are pruned later by orphan check).
2. Fetches all of the current user's own Spotify playlists (paginated), filters to those whose name contains
   "fusion" or "blues" (`fetch_all_playlists_from_spotify`).
3. For each matching playlist: `find_or_create_by!` the local `Playlist`, then for each Spotify track therein,
   `find_or_create_by!` `Track`/`Album`/`Artist`(s) and a `PlaylistTrack` join row.
4. Afterward, deletes any `Playlist`/`Track`/`Artist`/`Album` left with zero associated records (orphan cleanup)
   — this is what actually removes playlists/tracks that were unfollowed/removed on Spotify since last sync.
5. Returns a `ServiceInfo` object (created/deleted names per type) that the view renders as a sync summary.

`find_or_create_by!` is used throughout so re-running `build` is idempotent for existing records but does
**not** update fields on already-existing rows (e.g. renamed Spotify tracks/playlists won't be reflected locally
until the old row is deleted and recreated).

### Download flow

Both download services shell out to the external `spotdl` Python CLI (must be installed and on PATH; not a
gem/bundled dependency) via `system(...)`, always after `Dir.chdir`-ing into `downloads/tracks`:

- `DownloadPlaylistService` (`playlists#download`) — `spotdl sync <playlist_url> --save-file <name>.spotdl
  --user-auth --format m4a`. Uses spotdl's own sync/save-file state to skip already-downloaded tracks.
- `DownloadTrackService` (`tracks#download`) — downloads only tracks for which `Track#track_path` currently
  returns nil (i.e. not yet found on disk), one `spotdl download` call for the whole batch.

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
