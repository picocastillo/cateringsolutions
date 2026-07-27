class Select2LocalInput < SimpleForm::Inputs::CollectionSelectInput
  def initialize *args
    super
    @options.reverse_merge! label: object.class.human_attribute_name(@attribute_name)
    @input_html_options[:data] ||= {}
    @input_html_options[:data].reverse_merge! placeholder: 'Seleccione un registro ...'
    @input_html_options[:class] << 'select2-local'
    @input_html_options[:class] << 'input-xlarge' unless @input_html_options[:class].any? do |cs|
      cs.to_s.include?('input-')
    end
    @attribute_name = @attribute_name =~ /(_any|_eq|_ids|_id)$/ ? @attribute_name : "#{@attribute_name}_id"
  end
end
