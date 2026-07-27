module OnConstMissingDetection
  def on_const_missing_detect_by(attrib)
    instance_eval %{
      def const_missing name
        if const_defined? name
          const_get name
        else
          obj = all.detect { |obj| obj.send(:#{attrib}).sanitize.upcase == name.to_s }
          obj ? const_set(name, obj) : super
        end
      end
    }, __FILE__, __LINE__ - 9
  end
end
