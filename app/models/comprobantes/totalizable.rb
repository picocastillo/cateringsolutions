module Comprobantes
  module Totalizable
    def importe_total
      load_target.map(&:importe).sum
    end
  end
end
