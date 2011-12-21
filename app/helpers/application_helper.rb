module ApplicationHelper

  def logo
    image_tag('logo.png', :alt => 'Sample App', :class => 'round', :width => 200, :height => 55)
  end

  # Define a title on a per-page basis
  def title
    base_title = "Ruby on Rails Tutorial Sample App"
    if @title.nil?
      base_title
    else
      "#{base_title} | #{@title}"
    end
  end
end
