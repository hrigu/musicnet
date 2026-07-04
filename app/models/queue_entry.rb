# frozen_string_literal: true

class QueueEntry < ApplicationRecord
  belongs_to :track

  MAX_SIZE = 5

  def self.full?
    count >= MAX_SIZE
  end
end
