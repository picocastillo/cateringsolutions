class ApplicationForm
  include Virtus.model
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations

  def persisted?
    false
  end

  def self.belongs_to(association, class_name)
    class_eval <<-EOR, __FILE__, __LINE__ + 1
      attr_accessor :"#{association}_id"

      def #{association}
        @#{association} ||= #{class_name.name}.find_by_id #{association}_id
      end

      def #{association}= r
        @#{association} = r
        @#{association}_id = r.id if r.respond_to?(:id)
      end
    EOR
  end

  def self.has_many(association, class_name)
    class_eval <<-EOR, __FILE__, __LINE__ + 1
      attr_accessor :#{association}_ids

      def #{association}
        ids = #{association}_ids.is_a?(String) ? #{association}_ids.split(',') : #{association}_ids
        @#{association} ||= #{class_name.name}.where id: ids
      end

      def #{association}= rs
        @#{association} = rs
        @#{association}_ids = rs.map(&:id)
      end
    EOR
  end
end
