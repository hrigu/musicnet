module ApplicationHelper
  def engergie_to_view e
    (e * 100).round if e
  end
  def tempo_to_view e
    e.round if e
  end

end
