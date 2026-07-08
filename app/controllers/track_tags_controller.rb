# frozen_string_literal: true

# Manuelles Zuweisen eines Tags an einen Track von der Detailseite aus (Intent 79) - ergaenzt
# die automatische Zuordnung durch assign_track_tags. Entweder ein bestehender Tag (tag_id, aus
# der Livesuche TagsController#search) oder ein neuer (tag_name + category_id, danach wie ein
# bestehender find_or_create_by! - verhindert Duplikate, falls der Name in der Kategorie doch
# schon existiert).
class TrackTagsController < ApplicationController
  NO_TAG_SELECTED_ALERT = "Bitte einen Tag auswählen oder einen Namen mit Kategorie angeben."

  # @track wird in beiden Zweigen gesetzt (nicht nur bei Erfolg), da create.turbo_stream.erb in
  # jedem Fall die Tags-Zelle dieses Tracks neu rendert (Intent 83) - bei einem ungueltigen
  # Aufruf (kein Tag gewaehlt) unveraendert, ohne dass das Template das gesondert wissen muss.
  def create
    @track = Track.find(params[:track_id])
    tag = resolve_tag

    return respond_with_no_tag_selected if tag.nil?

    save_track_tag(tag)

    respond_to do |format|
      format.turbo_stream
      format.html { respond_html_after_create(tag) }
    end
  end

  def destroy
    track_tag = TrackTag.find(params[:id])
    track = track_tag.track
    tag_name = track_tag.tag.name
    track_tag.destroy
    redirect_to track_path(track), notice: "Tag \"#{tag_name}\" entfernt."
  end

  # Inline-Editieren der Staerke direkt in der Tracks-Tabelle (Intent 81) - eigene Action statt in
  # #create mitzuerledigen, da hier immer ein bestehender TrackTag per :id gemeint ist, nie eine
  # neue Zuordnung. @saved steuert im turbo_stream-Template (update.turbo_stream.erb), ob wieder
  # die Badge-Ansicht oder (bei einem Validierungsfehler) das Eingabefeld mit Fehlermeldung
  # gerendert wird.
  def update
    @track_tag = TrackTag.find(params[:id])
    @track_tag.strength = params.dig(:track_tag, :strength) || params[:strength]
    @saved = @track_tag.save

    respond_to do |format|
      format.turbo_stream
      format.html do
        if @saved
          redirect_to track_path(@track_tag.track), notice: "Tag \"#{@track_tag.tag.name}\" aktualisiert."
        else
          redirect_to track_path(@track_tag.track), alert: @track_tag.errors.full_messages.to_sentence
        end
      end
    end
  end

  private

  def respond_with_no_tag_selected
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to track_path(@track), alert: NO_TAG_SELECTED_ALERT }
    end
  end

  def save_track_tag(tag)
    @track_tag = @track.track_tags.find_or_initialize_by(tag: tag)
    @track_tag.strength = params[:strength]
    @saved = @track_tag.save
    @track.reload
  end

  def respond_html_after_create(tag)
    if @saved
      redirect_to track_path(@track), notice: "Tag \"#{tag.name}\" hinzugefügt."
    else
      redirect_to track_path(@track), alert: @track_tag.errors.full_messages.to_sentence
    end
  end

  def resolve_tag
    return Tag.find_by(id: params[:tag_id]) if params[:tag_id].present?
    return nil if params[:tag_name].blank? || params[:category_id].blank?

    category = Category.find_by(id: params[:category_id])
    return nil unless category

    name = params[:tag_name].strip
    category.tags.find_or_create_by!(name: name) { |t| t.aliases = name }
  end
end
