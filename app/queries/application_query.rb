class ApplicationQuery < ApplicationForm
  attribute :autorun, Boolean, default: true

  delegate :to_a, :count, :size, :page, :first, :last, :all, :each_record_in_ordered_batches, :empty?, :any?,
           :map, :to_sql, :limit, :per_page, :includes, :order, :eager_load, :reorder, to: :run

  def run
    Timeout.timeout 60 do
      if autorun && valid?
        relation
      else
        Usuarios::Usuario.none
      end
    end
  end

  def to_params
    (instance_variables - [:@autorun, :@errors, :@validation_context]).each_with_object({}) do |v, ps|
      ps[v.to_s.sub('@', '')] = instance_variable_get(v).to_param
    end
  end
end
