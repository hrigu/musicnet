# frozen_string_literal: true

class CategoriesController < ApplicationController
  def index
    @categories = Category.includes(:tags).order(:name)
  end

  def new
    @category = Category.new
  end

  def create
    @category = Category.new(category_params)
    if @category.save
      redirect_to categories_path, notice: "Kategorie erstellt."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @category = Category.find(params[:id])
  end

  def update
    @category = Category.find(params[:id])
    if @category.update(category_params)
      redirect_to categories_path, notice: "Kategorie gespeichert."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    Category.find(params[:id]).destroy
    redirect_to categories_path, notice: "Kategorie gelöscht."
  end

  private

  def category_params
    params.require(:category).permit(:name, :color, :hidden_for_assignment)
  end
end
