class Select2Input < SimpleForm::Inputs::StringInput
  def initialize *args
    super
    @options.reverse_merge! label: object.class.human_attribute_name(@attribute_name)
    @input_html_options[:data].reverse_merge! pre: object.send(@attribute_name).to_json
    @input_html_options[:class] << 'select2-remote'
    @attribute_name = @attribute_name =~ /(_any|_eq|_ids|ids_|_id|_csv)$/ ? @attribute_name : "#{@attribute_name}_id"
  end
end
