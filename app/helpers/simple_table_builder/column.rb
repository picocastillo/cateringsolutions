module SimpleTableBuilder
  class Column
    extend Memoist

    delegate :collection, :template, :options, to: :@builder
    delegate :content_tag, :capture, :number_to_currency, to: :template

    def initialize(builder, name, options, &block)
      @builder = builder
      @name = name
      @options = options
      @html_options = options.dup.slice! :header, :footer, :header_options, :footer_options, :if_blank, :format,
                                         :hide_if_empty, :helper
      @block = block
    end

    def render_head
      return if hide_column?

      content_tag :th, header.html_safe, construct_cell_options.merge(Hash(@options[:header_options]))
    end

    def render_body(object, row_idx)
      return if hide_column?

      content = body(object, row_idx)
      content_tag :td, content, construct_cell_options(object)
    end

    def render_foot
      return if hide_column?

      content_tag :td, format(footer), construct_cell_options.merge(Hash(@options[:footer_options]))
    end

    def footer?
      @options[:footer]
    end

    private

    def klass
      collection[0].try(:class)
    end

    def header
      @options[:header] or
        (@name.is_a?(String) && @name) or
        klass.respond_to?(:human_attribute_name) ? klass.human_attribute_name(@name) : @name.to_s.titleize
    end

    def body(object, row_idx)
      content = content object, row_idx
      content = @options[:if_blank] if @options[:if_blank] && content.blank?
      format content
    end

    def footer
      case @options[:footer]
      when :sum
        column_contents.sum
      when :avg
        column_contents.compact_blank.map(&:to_f).avg
      else
        @options[:footer]
      end
    end

    def content(object, row_idx)
      if @block
        capture do
          result = @block.call(object, row_idx)
          result = Array(result).compact.join.html_safe if actions?
          [Numeric, Danconia::Money, FalseClass, TrueClass].any? { |c| result.is_a?(c) } ? (return result) : result.to_s
        end
      elsif @name.is_a? String
        ''
      elsif @options[:helper]
        template.send @options[:helper], object
      else
        object.send @name
      end
    end
    memoize :content

    def column_contents
      collection.map.with_index { |object, idx| content object, idx }
    end
    memoize :column_contents

    def hide_column?
      (@options[:hide_if_empty] || @builder.options[:hide_empty_columns]) && column_contents.all?(&:blank?)
    end
    memoize :hide_column?

    def static_cell_css
      [].tap do |css|
        css << @name.to_s.sanitize if @name.is_a?(Symbol) && !actions?
        css << 'right' if !@html_options[:class] && column_contents.any? { |c| c.is_a?(Numeric) || c.is_a?(Danconia::Money) }
        css << 'center' if !@html_options[:class] && column_contents.any? { |c| !!c == c }
      end
    end
    memoize :static_cell_css

    def construct_cell_options(object = nil)
      custom_class = if @html_options[:class].respond_to?(:call)
                       @html_options[:class].call(object) if object
                     else
                       @html_options[:class]
                     end
      css = static_cell_css + [custom_class].flatten
      { class: css.compact_blank.join(' ') }
    end

    def actions?
      @html_options[:class].to_s.include? 'actions'
    end

    def format(content)
      return if content.nil?

      if @options[:format].is_a?(String)
        @options[:format] % content
      elsif @options[:format].is_a?(Symbol)
        template.send @options[:format], content
      elsif content.boolean?
        content.to_sino
      elsif content.respond_to? :to_sentence
        content.to_sentence
      else
        content
      end
    end
  end
end
