module Usuarios
  class Rol < ApplicationRecord
    has_many :roles_asignados, class_name: 'Usuarios::RolAsignado'
    has_many :usuarios, through: :roles_asignados, class_name: 'Usuarios::Usuario'
    serialize :transitivos, coder: YAML

    def self.[](rol)
      find_by(nombre: rol.to_s) or raise "Rol '#{rol}' no definido"
    end

    def self.modulo_start_with_any *modulos
      or_condition = modulos.map { |modulo| "modulo.start_with('#{modulo}')" }.join(' | ')
      where { instance_eval or_condition }
    end

    def self.protegidos
      Rol.modulo_start_with_any 'Usuarios'
    end

    def self.sugeridos
      self[:comprador]
    end

    def self.configurables_admin
      evitar = [Rol[:robot], Rol[:comprador], Rol[:administrador_empresa]]
      all.reject { |x| evitar.include?(x) }
    end

    def ==(other)
      case other
      when Symbol, String
        nombre.to_s == other.to_s
      else
        nombre == other.nombre
      end
    end

    def to_s
      titulo
    end

    def transitivos
      @transitivos ||= Rol.where(nombre: super).to_a.flat_map { |r| [r, *r.transitivos] }
    end

    def promotor?
      nombre == 'promotor'
    end
  end
end
