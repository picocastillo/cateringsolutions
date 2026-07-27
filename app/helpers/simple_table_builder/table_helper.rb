module SimpleTableBuilder
  module TableHelper
    def table_for(collection, options = {}, &)
      TableBuilder.new(Array(collection), self, options).render(&)
    end
  end
end
