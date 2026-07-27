module SimpleTableBuilder
  class TableBuilder
    attr_reader :collection, :template, :options

    delegate :content_tag, :capture, :dom_id, to: :@template

    def initialize(collection, template, options)
      options[:class] = 'table stylish-table' if options[:class].blank?
      @collection = collection
      @template = template
      @options = options
      @html_options = options.slice! :tr, :hide_empty_columns, :render_if_empty
      @columns = []
    end

    def render
      yield self if block_given?
      if collection.empty?
        empty_table
      else
        content_tag :table, @html_options do
          thead << tbody << tfoot
        end
      end
    end

    def column(name, options = {}, &)
      @columns << Column.new(self, name, options, &)
    end

    def columns *names, **options
      names.each { |name| column name, options }
    end

    def actions(&)
      column('Acciones', class: 'actions', hide_if_empty: true, &)
    end

    private

    def thead
      content_tag :thead do
        content_tag :tr, @columns.map(&:render_head).compact.join.html_safe
      end
    end

    def tbody
      content_tag :tbody do
        collection.map.with_index { |object, index| tbody_tr object, index }.join.html_safe
      end
    end

    def tbody_tr(object, index)
      html_options = construct_tr_options object
      content_tag :tr, html_options do
        @columns.map { |c| c.render_body object, index }.compact.join.html_safe
      end
    end

    def tfoot
      return unless @columns.any?(&:footer?)

      content_tag :tfoot do
        content_tag :tr, @columns.map(&:render_foot).compact.join.html_safe
      end
    end

    def empty_table
      @options[:render_if_empty] = 'No se encontraron resultados.' unless @options.key?(:render_if_empty)
      return unless @options[:render_if_empty]

      content_tag :table, @html_options do
        content_tag :tr do
          content_tag :td, @options[:render_if_empty], class: 'no-results'
        end
      end
    end

    def construct_tr_options(object)
      html_options = {}
      if @options[:tr]
        if (tr_class = @options[:tr][:class])
          html_options[:class] = tr_class.respond_to?(:call) ? tr_class.call(object) : tr_class
        end
        html_options[:id] = dom_id(object) if @options[:tr][:id] == :dom_id
      end
      html_options
    end
  end
end
