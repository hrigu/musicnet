# frozen_string_literal: true

module ApplicationHelper
  def engergie_to_view(e)
    (e * 100).round if e
  end

  def tempo_to_view(e)
    e&.round
  end

  # Eine Abfrage pro Request reicht - die Tabelle ist auf QueueEntry::MAX_SIZE Zeilen gedeckelt.
  def queued_track_ids
    @queued_track_ids ||= QueueEntry.pluck(:track_id)
  end
end
