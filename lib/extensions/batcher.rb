module Batcher
  # Equivalente al in_batches de Rails.
  # La diferencia es que los de Rails no permiten setear un order lo cual es necesario en ciertas consultas
  # NOTA: Usar en un scope con order xq sino mysql puede retornar resultados no determinísticos
  def in_ordered_batches(options = {})
    return to_enum(:in_ordered_batches, options) unless block_given?

    batch_size = options.fetch :batch_size, 1000
    load = options.fetch :load, false

    scope = is_a?(ActiveRecord::Relation) ? self : all
    page = 1
    remaining = scope.limit_value.to_i if scope.limit_value

    loop do
      offset = (page - 1) * batch_size
      limit = scope.limit_value ? [remaining, batch_size].min : batch_size

      batch = scope.limit(limit).offset(offset)

      if load
        records = batch.records
        ids = records.map(&:id)
        yielded_relation = batch
        # Esto hace que cuando el block que recibe la yielded_relation la recorra, ya tenga los objetos levantados y no vuelva a ejecutar la consluta
        yielded_relation.send(:load_records, records)
      else
        ids = batch.ids
        # Para traer los records x id no necesito el where y order original, y de hecho las consultas suelen ser mas lentas con ellos
        yielded_relation = scope.except(:where, :order).where(id: ids)
      end

      yield yielded_relation unless ids.empty?

      break if ids.length < batch_size

      if scope.limit_value
        remaining -= ids.length
        break if remaining <= 0 # Saves a useless iteration when the limit is a multiple of the batch size
      end

      page += 1
    end
  end

  def each_record_in_ordered_batches(options = {}, &)
    enum = Enumerator.new do |y|
      in_ordered_batches(options.reverse_merge(load: true)) do |batch|
        batch.each { |r| y << r }
      end
    end

    block_given? ? enum.each(&) : enum
  end
end

ActiveSupport.on_load(:active_record) { extend Batcher }
ActiveRecord::Relation.include Batcher

class Array
  def each_record_in_ordered_batches(_options = {}, &)
    each(&)
  end
end
