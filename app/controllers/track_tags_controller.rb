# frozen_string_literal: true

# Manuelles Zuweisen eines Tags an einen Track von der Detailseite aus (Intent 79) - ergaenzt
# die automatische Zuordnung durch assign_track_tags. Entweder ein bestehender Tag (tag_id, aus
# der Livesuche TagsController#search) oder ein neuer (tag_name + category_id, danach wie ein
# bestehender find_or_create_by! - verhindert Duplikate, falls der Name in der Kategorie doch
# schon existiert).
class TrackTagsController < ApplicationController
  def create
    track = Track.find(params[:track_id])
    tag = resolve_tag

    if tag.nil?
      return redirect_to track_path(track), alert: "Bitte einen Tag auswählen oder einen Namen mit Kategorie angeben."
    end

    track_tag = track.track_tags.find_or_initialize_by(tag: tag)
    track_tag.strength = params[:strength]

    if track_tag.save
      redirect_to track_path(track), notice: "Tag \"#{tag.name}\" hinzugefügt."
    else
      redirect_to track_path(track), alert: track_tag.errors.full_messages.to_sentence
    end
  end

  def destroy
    track_tag = TrackTag.find(params[:id])
    track = track_tag.track
    tag_name = track_tag.tag.name
    track_tag.destroy
    redirect_to track_path(track), notice: "Tag \"#{tag_name}\" entfernt."
  end

  private

  def resolve_tag
    return Tag.find_by(id: params[:tag_id]) if params[:tag_id].present?
    return nil if params[:tag_name].blank? || params[:category_id].blank?

    category = Category.find_by(id: params[:category_id])
    return nil unless category

    name = params[:tag_name].strip
    category.tags.find_or_create_by!(name: name) { |t| t.aliases = name }
  end
end
