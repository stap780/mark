module ApplicationHelper
  def turbo_id_for(obj)
    obj.persisted? ? obj.id : obj.hash
  end

  def sortable_with_badge(position)
    content_tag :div, class: 'js-sort-handle text-base relative cursor-grab active:cursor-grabbing mr-2 pt-1 inline-block' do
      concat sortable_icon
      concat content_tag(:span, position, class: 'absolute -top-1 -right-1 bg-blue-500 text-white text-xs px-1.5 py-0.5 rounded-full border border-white', data: { sortable_target: 'position' })
    end
  end

  def sortable_icon
    '<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 inline-block" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16V4m0 0L3 8m4-4l4 4m6 0v12m0 0l4-4m-4 4l-4-4" />
    </svg>'.html_safe
  end
end
