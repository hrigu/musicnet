# frozen_string_literal: true

class DjSessionPlayback < ApplicationRecord
  belongs_to :user
  belongs_to :track

  validates :played_at, presence: true

  scope :recent_first, -> { order(played_at: :desc, id: :desc) }

  # Faustregel statt echter Session-Modellierung (siehe Intent 87, 3.1): zwei Playbacks gelten als
  # dieselbe Auflegephase, solange die Luecke zwischen ihnen diese Schwelle nicht ueberschreitet.
  SESSION_GAP = 45.minutes

  # Gruppiert eine bereits nach played_at sortierte Liste (auf- oder absteigend) in Sessions -
  # jede neue Gruppe beginnt, sobald die Luecke zum vorherigen Eintrag SESSION_GAP ueberschreitet.
  def self.group_into_sessions(playbacks, gap: SESSION_GAP)
    playbacks.each_with_object([]) do |playback, groups|
      previous = groups.last&.last
      if previous && (previous.played_at - playback.played_at).abs <= gap
        groups.last << playback
      else
        groups << [playback]
      end
    end
  end
end
