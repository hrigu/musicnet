class TagsController < ApplicationController
  MAX_SEARCH_RESULTS = 10

  # Livesuche fuers manuelle Zuweisen eines Tags an einen Track (Intent 79) - liefert pro Treffer
  # auch die Kategorie mit, damit der DJ auf Anhieb sieht, wohin ein bestehender Tag gehoert.
  def search
    term = params[:term].to_s.strip
    tags = term.blank? ? [] : Tag.includes(:category)
                                  .where("LOWER(tags.name) LIKE ?", "%#{term.downcase}%")
                                  .order(:name)
                                  .limit(MAX_SEARCH_RESULTS)

    render json: tags.map { |tag| { id: tag.id, name: tag.name, category: tag.category.name } }
  end

  def new
    @category = Category.find(params[:category_id])
    @tag = @category.tags.new
  end

  def create
    @category = Category.find(params[:category_id])
    @tag = @category.tags.new(tag_params)
    if @tag.save
      redirect_to categories_path, notice: "Tag erstellt."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @tag = Tag.find(params[:id])
    @category = @tag.category
  end

  def update
    @tag = Tag.find(params[:id])
    if @tag.update(tag_params)
      redirect_to categories_path, notice: "Tag gespeichert."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    Tag.find(params[:id]).destroy
    redirect_to categories_path, notice: "Tag gelöscht."
  end

  private

  def tag_params
    params.require(:tag).permit(:name, :category_id, :aliases)
  end
end
