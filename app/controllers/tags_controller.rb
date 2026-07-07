class TagsController < ApplicationController
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
