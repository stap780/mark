module LiquidDrops
  class WebformDrop < ::Liquid::Drop
    def initialize(webform)
      @webform = webform
    end

    def title
      @webform.respond_to?(:title) ? @webform.title : nil
    end

    def kind
      @webform.respond_to?(:kind) ? @webform.kind : nil
    end
  end
end


