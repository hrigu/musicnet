# frozen_string_literal: true

class DjSessionPlayback < ApplicationRecord
  belongs_to :user
  belongs_to :track

  validates :played_at, presence: true

  scope :recent_first, -> { order(played_at: :desc, id: :desc) }
end
