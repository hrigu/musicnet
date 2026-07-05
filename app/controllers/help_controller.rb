class HelpController < ApplicationController
  # doc/track_search_syntax.md ist die einzige Quelle für diesen Artikel - hier nur zur
  # Laufzeit als HTML gerendert, keine zweite, separat zu pflegende Kopie (Intent 46).
  MARKDOWN_RENDERER = Redcarpet::Markdown.new(Redcarpet::Render::HTML, fenced_code_blocks: true, tables: true)

  def search_syntax
    markdown = Rails.root.join("doc/track_search_syntax.md").read
    @html = MARKDOWN_RENDERER.render(markdown)
  end
end
