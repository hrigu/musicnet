# frozen_string_literal: true

class LibrariesController < ApplicationController
  def index
    @libraries = Library.order(:name)
  end

  def new
    @library = Library.new
  end

  def create
    @library = Library.new(library_params)
    if @library.save
      @library.resync_playlist_assignments!
      redirect_to libraries_path, notice: "Bibliothek erstellt."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @library = Library.find(params[:id])
  end

  def update
    @library = Library.find(params[:id])
    if @library.update(library_params)
      @library.resync_playlist_assignments!
      redirect_to libraries_path, notice: "Bibliothek gespeichert."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    Library.find(params[:id]).destroy
    redirect_to libraries_path, notice: "Bibliothek gelöscht."
  end

  private

  def library_params
    params.require(:library).permit(:name, :keyword)
  end
end
