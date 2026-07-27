module PanelHelper
  def panel(...)
    PanelBuilder.new(self, ...).render
  end

  class PanelBuilder
    delegate :content_tag, :link_to_function, to: :@template

    def initialize template, label, html: {}, **options, &block
      @template = template
      @label = label
      @html_options = html
      @options = options.reverse_merge toggle: options.key?(:start_toggled), show_toggle_button: true
      @block = block
    end

    def render
      content_tag :div,
                  @html_options.reverse_merge(class: "panel col-12 panel-#{@label.sanitize} #{@options[:class]}".strip,
                                              id: "panel-#{@label.sanitize}") do
        (@options[:header] == false ? content : header + content)
      end
    end

    def header
      content_tag :div, class: 'panel-header col-12 col-sm-12' do
        label + subtitle + actions
      end
    end

    def content
      content_tag :div, class: "panel-content #{'hide-please' if @options[:start_toggled]}", &@block
    end

    def label
      content_tag :span, @label, class: 'panel-label'
    end

    def subtitle
      return '' if @options[:subtitle].blank?

      content_tag :span, @options[:subtitle], class: 'panel-subtitle'
    end

    def actions
      @actions = []
      @actions.concat Array(@options[:actions]).compact if @options[:actions]
      @actions << link_to_function(toggle_label, class: 'panel-toggle', tabindex: -1) if @options[:toggle] && @options[:show_toggle_button]
      @actions.empty? ? '' : content_tag(:span, @actions.join(' | ').html_safe, class: 'panel-actions')
    end

    def toggle_label
      @options[:start_toggled] ? 'Mostrar' : 'Ocultar'
    end
  end
end
