class Album < ApplicationRecord
  has_many :tracks
  has_and_belongs_to_many :artists


end
