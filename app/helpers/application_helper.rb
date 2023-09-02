module ApplicationHelper
  def engergie_to_view e
    (e * 100).round
  end
  def tempo_to_view e
    e.round
  end

end
