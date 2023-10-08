# frozen_string_literal: true

class Playlist < ApplicationRecord
  has_many :playlist_tracks
  has_many :tracks, through: :playlist_tracks

  COLORS = %i[green blue yellow red lila orange xyz].freeze

  CONTEXT = [
    'bg-primary',
    'bg-secondary',
    'bg-success',
    'bg-danger',
    'bg-warning',
    'bg-info',
    # "bg-light",
    'bg-dark'
  ].freeze

  COLORS_TO_CONTEXT = {
    green: 'bg-success',
    blue: 'bg-primary',
    yellow: 'bg-warning',
    red: 'bg-danger',
    lila: 'bg-info',
    orange: 'bg-secondary',
    xyz: 'bg-dark'
  }.freeze

  TAGS = {
    next: { color: :green },
    blues: { color: :blue },
    minimalistic: { color: :yellow },
    opulent: { color: :red },
    romantik: { color: :yellow },
    triphop: { color: :blue },
    smart: { color: :orange },
    sweet: { color: :orange },
    'tender zart': { color: :orange },
    groove: { color: :lila },
    happy: { color: :green },
    'heavy fett': { color: :blue },
    'encore schluss': { color: :red },
    'french francais': { color: :red },
    jungle: { color: :green },
    hymnisch: { color: :lila },
    love: { color: :orange },
    accustic: { color: :blue },
    dark: { color: :red },
    classic: { color: :blue },
    piano: { color: :blue },
    dream: { color: :green },
    sad: { color: :blue },
    verspielt: { color: :yellow },
    '?':  { color: :green },
    africa: { color: :yellow },
    suisse: { color: :yellow },
    '80ies sort of': { color: :lila },
    skurril: { color: :yellow },
    song: { color: :blue },
    'classic cover': { color: :green },
    melody: { color: :yellow },
    tango: { color: :green },
    best: { color: :green },
    'unregelmässiger Takt': { color: :green },
    rock: { color: :green },
    hiphop: { color: :green },
    lied: { color: :green },
    'experimental electronica': { color: :green },
    funk: { color: :green },
    reggea: { color: :green },
    floating: { color: :green },
    Waltz: { color: :green },
    jazz: { color: :red },
    Drama: { color: :lila },
    techno: { color: :blue },
    worldmusic: { color: :green },
    swing: { color: :green },
    energie: { color: :yellow },
    soul: { color: :orange },
    kitsch: { color: :green },
    latin: { color: :blue },
    arabisch: { color: :red },
    crossover: { color: :yellow },
    'contemporary classical': { color: :green },
    cover: { color: :red },
    renaissance: { color: :blue },
    melancolia: { color: :yellow },
    mystery: { color: :orange },
    story: { color: :blue },
    avantgarde: { color: :orange },
    cool: { color: :green },
    simple: { color: :red },
    mainstream: { color: :yellow }
  }.freeze

  def color_class
    color = TAGS.dig(short_name.downcase.to_sym, :color) || :xyz
    COLORS_TO_CONTEXT[color] || 'bg-light'
  end

  def short_name
    n = name.remove('Fusion')
    n = n.remove('fusion')
    n.strip
  end

  def name_path_ready
    name.delete(' ')
  end
end
