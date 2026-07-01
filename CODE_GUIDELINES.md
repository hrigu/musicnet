# Code Guidelines

This document defines coding conventions for Musicnet. These apply to all Ruby, Rails, and spec code.

## 1. Ruby Style

- Run `bundle exec rubocop` to verify style. No `.rubocop.yml` is checked in, so default cops apply — stay consistent with surrounding code rather than assuming project-specific overrides.
- Target Ruby version: **3.2.2** (see `.ruby-version` / `Gemfile`).
- Use double-quoted strings (stay consistent with surrounding code).

## 2. Naming

- **Classes / Modules**: `PascalCase` matching the file path, e.g. `DownloadPlaylistService` in `app/services/download_playlist_service.rb`.
- **Methods**: `snake_case`.
- **Predicates**: end in `?`, never use `is_`, e.g. `downloaded?` not `is_downloaded`.
- **Bang methods**: use `!` only for the destructive/raising variant of a method that has a safe counterpart.
- Identifiers (classes, methods, variables) are English, per this project's model/service names (`Track`, `Playlist`, `BuildMusicNetService`). Comments and commit messages are German — see `AGENTS.md`.

## 3. Classes & Modules

- Keep classes small and single-purpose (Single Responsibility Principle).
- Prefer `attr_reader` / `attr_accessor` over manual `def` accessors.
- `private` methods below the public interface, separated by a blank line.
- Avoid `protected` unless there's a concrete inheritance reason.
- Do **not** use `defdelegate` to forward API calls — keep the method body explicit to preserve the API contract.

## 4. Methods

- Keep methods short. If a method exceeds ~10 lines, consider extracting helpers.
- One level of abstraction per method.
- Avoid deeply nested conditionals — use guard clauses (`return unless ...`).
- Avoid `else` after `return` / `raise`.

## 5. Comments

- Write comments only to explain **WHY**, never to describe **WHAT** the code does.
- Well-named methods and variables should make the WHAT self-evident.
- Module-level `##` doc blocks are acceptable for public API documentation.
- Remove TODO comments before merging, or file a proper Intent/task.

## 6. Error Handling

- Rescue specific exception classes — avoid bare `rescue StandardError` unless in a top-level boundary (controllers, jobs).
- Log warnings with `Rails.logger.warn` before re-raising or rendering errors.

## 7. ActiveRecord

- Use scopes for reusable query fragments on models.
- Avoid `where` chains in controllers — move them to a model scope or a service object under `app/services/`.
- Always permit params explicitly with `params.require(...).permit(...)`.
- Use `find` when you expect the record to exist (raises `RecordNotFound`). Use `find_by` when absence is a valid case.
- Prefer `update` over `update_attribute` (the latter skips validations).

## 8. Testing

- Test framework: **RSpec** with `rspec-rails`. No FactoryBot, Timecop, or database_cleaner gem is installed — don't assume they're available.
- Spec type is inferred from file location (`config.infer_spec_type_from_file_location!`).
- Use YAML fixtures under `spec/fixtures/` for test data (`config.use_transactional_fixtures = true` handles cleanup between examples).
- Do **not** use stubs or mocks for DB/internal modules — test with real objects. Only mock external boundaries (HTTP APIs, webhooks, mail delivery).
- Helper methods shared across specs go in `spec/support/` if that pattern is introduced; none exists yet.
- Run a single spec file: `bundle exec rspec spec/path/to/file_spec.rb`.
- Run a single example: `bundle exec rspec spec/path/to/file_spec.rb:42`.
- Run the full suite: `RAILS_ENV=test bundle exec rspec spec`.

### 8.1 RSpec Style

- Use `expect(...).to_not` (enforced by `RSpec/NotToNot: to_not`).
- Prefer `let` / `let!` over instance variables in `before` blocks.
- One assertion per example when practical; group related assertions with `aggregate_failures`.
- Describe the subject clearly: `describe '.class_method'`, `describe '#instance_method'`.
- Use context blocks for variations: `context 'when team is locked'`.

## 9. Migrations

- Filename format: `YYYYMMDDHHMMSS_<description>.rb` — full precision including seconds.
- Always provide `up`/`down` or use `change` when reversibility is obvious.
- Do not reference model constants in migrations — use string class names or raw SQL to avoid future breakage.
- Migrations live in `db/migrate/`.

## 10. Language

- This is a single-user app for a Swiss DJ; views use hard-coded German strings directly (no i18n locale files are used for app content — `config/locales/` only holds Devise/date defaults). Swiss German spelling applies.
- Follow `AGENTS.md` for the split between German (comments, commit messages, user-facing text) and English (identifiers).

## 11. Git

- Never commit directly to `main`/`master` without review.
- Commit messages follow the format from the Development Workflow Task Completion Protocol.
- Keep commits atomic — one logical change per commit.