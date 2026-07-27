module SerializeIds
  def serialize_ids(attr_name, clazz, options = {})
    clazz = clazz.constantize if clazz.is_a?(String)
    options[:sort_by] ||= options[:csv_accessor] || :index
    class_eval <<-EOR, __FILE__, __LINE__ + 1
      def #{attr_name}_ids= ids
        self[:#{attr_name}_ids] = ids.is_a?(Array) ? ids.select(&:present?).join(',') : ids
      end

      def #{attr_name}_ids
        self[:#{attr_name}_ids].to_s.split(',').map(&:to_i)
      end

      def #{attr_name}= objects
        objects = objects.map { |o| #{clazz}[o] } if objects.first.is_a?(Symbol)
        @#{attr_name} = SerializedArray.new objects, self, '#{attr_name}'
        self.#{attr_name}_ids = objects.map(&:id)
      end

      def #{attr_name}
        @#{attr_name} ||= begin
          ids = #{attr_name}_ids.map(&:to_i)
          objects = #{clazz}.respond_to?(:where) ? #{clazz}.where(id: ids) : #{clazz}.find_all_by_id(ids)
          objects = if :#{options[:sort_by]} == :index
            objects.sort_by { |o| ids.index o.id }
          else
            objects.sort_by &:#{options[:sort_by]}
          end
          SerializedArray.new objects, self, '#{attr_name}'
        end
      end
    EOR
    class_eval <<-EOR, __FILE__, __LINE__ + 1 if options[:csv_accessor]
      def #{attr_name}_csv= csv
        self.#{attr_name} = #{clazz}.where(#{options[:csv_accessor]}: csv.to_s.split(',').map(&:strip)).to_a
      end

      def #{attr_name}_csv
        #{attr_name}.map(&:#{options[:csv_accessor]}).join ', '
      end
    EOR
  end
end

class SerializedArray < Array
  def initialize(array, owner, attr_name)
    super(array)
    @owner = owner
    @attr_name = attr_name
  end

  def <<(object)
    @owner.send "#{@attr_name}=", @owner.send(@attr_name.to_s) + [object]
    super
  end
end
