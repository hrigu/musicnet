# frozen_string_literal: true

desc 'erstelle die crates-Listen für mixxx'
task create_crates_lists: [:environment] do
  Playlist.all.each do |p|
    tracks = p.tracks
    track_pathes = []
    dir_name = Rails.root.join('downloads/tracks')
    tracks.each do |t|
      track_path = t.track_path
      track_pathes << "#{dir_name}/#{track_path}" if track_path.present?
    end
    file_name = "/home/christian/Documents/mixx/#{p.name}.m3u"
    puts "create '#{file_name}'"
    File.open(file_name, "w") do |f|
      track_pathes.each do |tp|
        f.puts(tp)
      end
    end
  end
end
