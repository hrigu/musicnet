class TrackTag < ApplicationRecord
  belongs_to :track
  belongs_to :tag

  validates :strength, presence: true, inclusion: { in: 1..10 }
  validates :tag_id, uniqueness: { scope: :track_id }
end
