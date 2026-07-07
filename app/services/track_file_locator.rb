# frozen_string_literal: true

class TrackFileLocator
  FILE_NAME_REPLACEMENTS = { ":" => "-", "?" => "", "/" => "", '"' => "'", "\\" => "" }.freeze

  def self.preload_track_paths(tracks)
    file_entries = download_file_entries
    tracks.each do |track|
      track.instance_variable_set(:@track_path, resolve_track_path(track, file_entries))
    end
  end

  def self.download_file_entries
    return [] unless Dir.exist?(downloads_dir)

    Dir.children(downloads_dir).sort
      .reject { |file_name| file_name.start_with?(".") }
      .map { |file_name| [file_name, file_name.downcase] }
  end

  def self.downloads_dir
    Rails.root.join("downloads/tracks")
  end

  def self.resolve_track_path(track, file_entries = download_file_entries)
    resolve_from_file_name(track) || resolve_from_name_match(track, file_entries)
  end

  def self.resolve_from_file_name(track)
    return unless track.file_name.present?

    path = downloads_dir.join(track.file_name)
    path.to_s if File.exist?(path)
  end

  def self.resolve_from_name_match(track, file_entries)
    search = track.name.gsub(Regexp.union(FILE_NAME_REPLACEMENTS.keys), FILE_NAME_REPLACEMENTS)
    suffix = "#{search}.m4a".downcase
    entry = file_entries.find { |_original, downcased| file_name_matches?(downcased, suffix) }
    Rails.logger.info("!!File nicht gefunden: #{search}") unless entry
    entry && downloads_dir.join(entry.first).to_s
  end

  def self.file_name_matches?(file_name, suffix)
    file_name.end_with?(suffix) &&
      file_name.length >= suffix.length + 2 &&
      file_name[file_name.length - suffix.length - 2] == "-"
  end
end
