class HelpController < ApplicationController
  # Jeder Artikel rendert eine doc/*.md-Datei zur Laufzeit als HTML - sie bleibt die einzige
  # Quelle, keine zweite, separat zu pflegende Kopie (Intent 46). Die Whitelist verhindert, dass
  # ein roher Dateiname aus der URL gelesen wird.
  ARTICLES = {
    "suche-syntax" => { title: "Suche", file: "track_search_syntax.md" },
    "installation" => { title: "Installation", file: "installation.md" },
    "bedienung" => { title: "Bedienung", file: "usage.md" },
    "diary" => { title: "Diary", file: "diary.md" }
  }.freeze

  MARKDOWN_RENDERER = Redcarpet::Markdown.new(Redcarpet::Render::HTML, fenced_code_blocks: true, tables: true)

  def show
    article = ARTICLES[params[:page]]
    return render(plain: "Not Found", status: :not_found) unless article

    @title = article[:title]
    markdown = Rails.root.join("doc", article[:file]).read
    @html = MARKDOWN_RENDERER.render(markdown)
  end
end
