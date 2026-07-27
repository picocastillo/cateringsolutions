class Exception
  def formatted
    bt = backtrace.try :join, "\n    "
    "\n#{self.class} (#{message}):\n    #{bt}\n\n"
  end

  def self.wrap(other_exception)
    wrapped = new other_exception.message
    wrapped.set_backtrace other_exception.backtrace
    wrapped
  end
end

class ErrorAplicacion < StandardError
  def initialize(array_or_string = nil)
    if array_or_string.is_a?(Array)
      @messages = array_or_string.uniq
      super(array_or_string.to_sentence)
    else
      super
    end
  end

  def message
    @messages or super
  end
end

class ObjetoNoEliminable < ErrorAplicacion
end

class AccesoNoAutorizado < StandardError
end

class AlicuotaNoEncontrada < ErrorAplicacion
end

class AtributoInvalido < ErrorAplicacion
  def initialize(condicion, atributo, _target, orig_ex)
    super("La condición #{condicion.id} no pudo evaluar el atributo #{atributo}. \nError original: #{orig_ex}")
  end
end

class InvalidQuery < StandardError
  def initialize(msg = nil)
    super("Consulta inválida: #{msg}")
  end
end
