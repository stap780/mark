module ApplicationHelper

  def format_account_setting(value)
    case value
    when TrueClass, FalseClass
      value ? t('yes', default: 'Yes') : t('no', default: 'No')
    when Array
      value.map { |v| format_account_setting(v) }.join(', ')
    when Hash
      value.map { |k, v| "#{k}: #{format_account_setting(v)}" }.join(', ')
    else
      value.to_s
    end
  end

  def show_link?(item)
    return true unless current_account
    
    # Non-partner accounts see all links
    return true unless current_account.partner?
    
    # Partner accounts need to have the specific app enabled
    current_account.partner_and_app_enabled?(item.to_s)
  end

  def turbo_id_for(obj)
    obj.persisted? ? obj.id : obj.hash
  end

  def account_subscription(account)
    @account_subscription_cache ||= {}
    @account_subscription_cache[account.object_id] ||= account.try(:current_subscription)
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

  def link_to_sidebar(text, path, active_if: nil, **options)
    base_classes = "group flex items-center px-3 py-2 text-sm font-medium rounded-lg text-white hover:bg-violet-500 hover:bg-opacity-75"
    active_class = "bg-violet-500 bg-opacity-75"
    
    active = if active_if.nil?
      request.path.include?(path.to_s)
    elsif active_if.is_a?(Proc)
      active_if.call
    elsif active_if.is_a?(String) || active_if.is_a?(Symbol)
      request.path.include?(active_if.to_s)
    else
      active_if
    end
    
    classes = "#{base_classes} #{active_class if active}"
    options[:class] = classes
    
    link_to text, path, options
  end

  def edit_icon
    '<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-violet-700" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
    </svg>'.html_safe
  end

  def link_to_edit(path, **options)
    # Если класс содержит текстовый стиль или bg-gray-100, заменяем на стиль иконки
    # Иначе используем переданный класс (например, для кнопок с bg-violet-600)
    if options[:class]&.include?('text-violet-700 hover:underline') || options[:class]&.include?('bg-gray-100')
      options[:class] = "p-2 rounded-md bg-violet-100 hover:bg-violet-200 flex items-center justify-center"
    elsif !options[:class]
      # Класс не указан - используем стиль иконки по умолчанию
      options[:class] = "p-2 rounded-md bg-violet-100 hover:bg-violet-200 flex items-center justify-center"
    end
    options[:title] ||= t('edit')
    
    link_to path, options do
      edit_icon
    end
  end

  def show_icon
    '<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-violet-700" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
    </svg>'.html_safe
  end

  def link_to_show(path, **options)
    # Если класс содержит текстовый стиль или bg-gray-100, заменяем на стиль иконки
    # Иначе используем переданный класс (например, для кнопок с bg-violet-600)
    if options[:class]&.include?('text-violet-700 hover:underline') || options[:class]&.include?('bg-gray-100')
      options[:class] = "p-2 rounded-md bg-violet-100 hover:bg-violet-200 flex items-center justify-center"
    elsif !options[:class]
      # Класс не указан - используем стиль иконки по умолчанию
      options[:class] = "p-2 rounded-md bg-violet-100 hover:bg-violet-200 flex items-center justify-center"
    end
    options[:title] ||= t('show')
    
    link_to path, options do
      show_icon
    end
  end

  def delete_icon
    '<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-red-700" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
    </svg>'.html_safe
  end

  def link_to_delete(path, **options)
    # Если класс содержит текстовый стиль или bg-gray-100, заменяем на стиль иконки
    # Иначе используем переданный класс (например, для кнопок с bg-red-600)
    if options[:class]&.include?('text-red-600 hover:underline') || options[:class]&.include?('bg-gray-100')
      options[:class] = "p-2 rounded-md bg-red-300 hover:bg-red-400 flex items-center justify-center"
    elsif !options[:class]
      # Класс не указан - используем стиль иконки по умолчанию
      options[:class] = "p-2 rounded-md bg-red-300 hover:bg-red-400 flex items-center justify-center"
    end
    options[:title] ||= t('delete')
    options[:data] ||= {}
    options[:data][:turbo_method] ||= :delete
    options[:data][:turbo_confirm] ||= t('delete_confirm', default: 'Are you sure?')
    
    link_to path, options do
      delete_icon
    end
  end

  # Change the default link renderer for will_paginate
  def will_paginate(collection_or_options = nil, options = {})
    if collection_or_options.is_a? Hash
      options, collection_or_options = collection_or_options, nil
    end
    unless options[:renderer]
      options = options.merge renderer: WillPaginate::ActionView::CustomRenderer
    end
    super *[collection_or_options, options].compact
  end
end
