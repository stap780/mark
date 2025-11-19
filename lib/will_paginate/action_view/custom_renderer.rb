require 'will_paginate/view_helpers/action_view'

module WillPaginate
  module ActionView
    class CustomRenderer < LinkRenderer
      def link(text, target, attributes = {})
        attributes['data-turbo'] = 'false'
        super
      end
    end
  end
end

