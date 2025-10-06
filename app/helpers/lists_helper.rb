module ListsHelper
  def list_icon_svg(list, active: false, classes: "h-5 w-5", style: nil)
    style ||= list.icon_style.presence || "icon_one"
    base_color = list.respond_to?(:icon_color) && list.icon_color.present? ? list.icon_color : "#999999"
    stroke = base_color
    fill = active ? base_color : "none"

    case style
    when "icon_one"
      # Heart
      %Q(<svg xmlns="http://www.w3.org/2000/svg" class="#{classes}" viewBox="0 0 24 24" fill="#{fill}" stroke="#{stroke}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 1 0-7.78 7.78L12 21.23l8.84-8.84a5.5 5.5 0 0 0 0-7.78z"/></svg>)
    when "icon_two"
      # Wishlist (bookmark)
      %Q(<svg xmlns="http://www.w3.org/2000/svg" class="#{classes}" viewBox="0 0 24 24" fill="#{fill}" stroke="#{stroke}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21l-7-5-7 5V5a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2z"/></svg>)
    when "icon_three"
      # Like (thumb/finger up)
      %Q(<svg xmlns="http://www.w3.org/2000/svg" class="#{classes}" viewBox="0 0 24 24" fill="#{fill}" stroke="#{stroke}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 21h4V9H2v12z"/><path d="M22 11c0-1.1-.9-2-2-2h-6l1-5-5 6v11h9c1.1 0 2-.9 2-2l1-8z"/></svg>)
    else
      ""
    end.html_safe
  end
end


