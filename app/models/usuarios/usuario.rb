require 'digest/sha1'
module Usuarios
  class Usuario < ApplicationRecord
    extend Memoist

    acts_as_discontinued
    before_validation :asignar_tienda
    before_validation :rectificar_roles
    before_save :prevent_super_admin_discontinuation
    before_save :encrypt_password
    before_destroy :prevent_super_admin_deletion

    has_many :roles_asignados, dependent: :destroy, class_name: 'Usuarios::RolAsignado'
    has_many :roles, through: :roles_asignados, class_name: 'Usuarios::Rol'
    has_many :pedidos, class_name: 'Pedidos::Pedido'
    has_many :pedidos_creados, class_name: 'Pedidos::Pedido', foreign_key: :autor_id
    has_many :favoritos, class_name: 'Productos::Favorito'
    has_many :preferencias, class_name: 'Usuarios::Preferencia'
    belongs_to :cuenta, class_name: 'Clientes::Cuenta', validate: false, optional: true
    belongs_to :local, class_name: 'Locales::Local', optional: true

    has_many :procesos, class_name: 'Infraestructura::Procesos::Proceso', foreign_key: :autor_id

    has_and_belongs_to_many :tiendas, class_name: 'Tiendas::Tienda', join_table: 'usuarios_tiendas',
                                      association_foreign_key: 'tienda_id', order: 'tiendas.nombre'

    belongs_to :visualizando_tienda, class_name: 'Tiendas::Tienda',
                                     optional: true
    belongs_to :visualizando_local, class_name: 'Locales::Local', optional: true

    belongs_to :tienda_cliente, class_name: 'Tiendas::Tienda', optional: true

    enum :servicio_de_impresion, class_name: 'Usuarios::ServicioDeImpresion', default: 1

    has_many :documentos, -> { order :position }, as: :documentable, dependent: :destroy, class_name: 'Infraestructura::Documento'
    has_many :imagenes, lambda {
      order(:position).where('documento_content_type like "%image%"')
    }, as: :documentable, dependent: :destroy, class_name: 'Infraestructura::Documento'

    # Virtual attribute for the unencrypted password
    attr_accessor :password, :administrador_de_empresa, :solicitar_cambio_contrasena

    VISTAS_PRODUCTOS = ['pasadores', 'lista'].freeze

    validates :nombre, presence: true
    validates :vista_productos, inclusion: { in: VISTAS_PRODUCTOS }
    # Tipo de usuario (1 = Cliente, 2 = Administrador) is mandatory. Without
    # this, the form silently surfaced only the cryptic
    # "Tienda cliente no puede estar en blanco" instead of the real cause.
    validates :tipo_usuario_id, inclusion: { in: [1, 2], message: 'debe seleccionarse (Cliente o Administrador)' }
    validates :dni, presence: { if: :tiene_cuenta? }
    validates :tienda_cliente_id, presence: { if: :tiene_cuenta? }
    validates :dni, uniqueness: { if: :tiene_cuenta? }
    validates       :dni, length: { within: 1..9, if: :tiene_cuenta? }
    validates       :password, length: { within: 6..40, if: :password_required? }
    validates :password, confirmation: { if: :password_required? }
    validates :password_confirmation, presence: { if: :password_required? }
    validates :login, length: { within: 1..40 }
    validates :login, uniqueness: { case_sensitive: false }
    validates :email, email: { multiple: true }

    validate :validar_cuenta

    validate :validar_local

    validate :solo_una_foto

    validates :cuit, cuit: true, allow_nil: true

    scope :by_login_or_nombre, ->(str) { where { login.eq(str) | nombre.start_with(str) } }
    scope :cumple_roles, lambda { |roles|
      where "(select count(*) from roles_asignados ra where ra.usuario_id = usuarios.id and ra.rol_id in (?)) = #{roles.size}", roles
    }
    scope :cumple_algun_rol, lambda { |roles|
      where 'exists (select 1 from roles_asignados ra where ra.usuario_id = usuarios.id and ra.rol_id in (?))', roles
    }
    scope :cumple_rol, ->(*roles_sym) { cumple_algun_rol(roles_sym.map { |r| Usuarios::Rol[r] }) }
    scope :de_clientes, -> { where.not cuenta_id: nil }
    scope :de_operadores, -> { where(cuenta_id: nil).where.not(id: robots.ids) }
    scope :robots, -> { cumple_rol :robot }
    scope :administradores, -> { cumple_rol :admin }

    delegate :can?, :cannot?, to: :ability

    delegate :cliente, to: :cuenta, allow_nil: true

    def estado_cuenta_corriente
      return unless cliente && cumple_rol?(:administrador_empresa)

      cliente.estado_cuenta_corriente self
    end
    memoize :estado_cuenta_corriente

    def saldo
      Danconia::Money.new(estado_cuenta_corriente.try(&:saldo_total).to_f)
    end

    def self.visibles_por(user)
      if user.admin?
        all
      else
        none
      end
    end

    def foto_safe
      imagenes.present? ? imagenes.first.url(:thumb) : '/user.png'
    end

    def self.authenticate(login, password, tienda = nil)
      u = find_by login: login
      if u&.authenticated?(password)
        return { result: :inactive_user } unless u.active?
        return { result: :tienda_no_autorizada } if tienda && !u.puede_loguearse_en?(tienda)

        { user: u, result: :ok }
      else
        { result: :wrong_credentials }
      end
    end

    def pedido_pendiente
      pedidos_creados.where(estado_id: 1).first
    end

    def pedidos_pendientes
      pedidos_creados.where(estado_id: 1)
    end

    def tiene_cuenta?
      cuenta.present?
    end

    def obtener_preferencia(n)
      preferencias.find { |x| x.nombre == n } || Usuarios::Preferencia.obtener(n, self)
    end

    def vista_lista?
      vista_productos == 'lista'
    end

    # Encrypts some data with the salt.
    def self.encrypt(password, salt)
      Digest::SHA1.hexdigest("--#{salt}--#{password}--")
    end

    # Encrypts the password with the user salt
    def encrypt(password)
      self.class.encrypt(password, salt)
    end

    def cliente?
      tipo_usuario_id == 1
    end

    def operador?
      !admin? && cuenta.blank?
    end

    def nombre_y_cliente
      "#{nombre} - #{cliente}"
    end

    def nombre_normalizado
      ns = nombre.split
      ns.compact_blank.map(&:downcase).map(&:capitalize).join(' ')
    end
    memoize :nombre_normalizado

    def authenticated?(password)
      crypted_password == encrypt(password)
    end

    def suscripcion(tipo_notificacion)
      suscripciones.detect { |cn| cn.tipo == tipo_notificacion }
    end

    def suscripto_a?(tipo_notificacion)
      suscripcion(tipo_notificacion)&.deseada?
    end

    def suscripciones_deseadas
      suscripciones.select(&:deseada?)
    end

    def nombre_legajo_dni_cliente
      l = legajo.present? ? "<span style='color: #aaa'>L</span>#{legajo} " : ''
      d = dni.present? ? "<span style='color: #aaa'>D</span>#{dni}" : ''
      "<div class='row'>
        <div class='col-6'>#{nombre}</div>
        <div class='col-6'>#{cliente}</div>
        <div class='col-6'>#{d}</div>
        <div class='col-6'>#{l}</div>
      </div>
      "
    end

    def to_s
      cuenta ? "#{nombre} / #{cuenta.cliente}" : nombre
    end

    def admin?
      cumple_rol? :admin
    end

    def tipo_usuario_html
      a = if cliente?
            cumple_rol?(:administrador_empresa) ? "Encargado de #{cuenta.cliente}" : cuenta.cliente.to_s
          else
            (admin? ? 'Administrador' : 'Operador')
          end
      a.html_safe
    end

    def robot?
      !admin? && cumple_rol?(:robot)
    end

    def cumple_rol?(rol)
      roles.any? { |r| r == :admin || r == rol || r.transitivos.include?(rol) }
    end

    def super_admin?
      id == 1
    end

    def admin_financiero?
      [1, 2864].include?(id)
    end

    def cumple_roles? *roles
      roles.all? { |rol| cumple_rol? rol }
    end

    def cumple_algun_rol? *roles
      roles.any? { |rol| cumple_rol? rol }
    end

    def roles=(roles)
      super(Array(roles).map { |r| r.is_a?(Usuarios::Rol) ? r : Usuarios::Rol[r] })
    end
    alias rol= roles=

    def accede_a_modulo? *modulos
      cumple_algun_rol?(*Usuarios::Rol.modulo_start_with_any(*modulos))
    end

    def abilities
      ability.send(:rules).map do |cd|
        [cd.base_behavior ? 'can' : 'cannot', cd.actions, cd.instance_variable_get('@subjects')].join(' ')
      end
    end

    def tienda_activa
      # Step 8 consolidation: cliente users now belong to multiple tiendas via
      # HABTM (cliente.tiendas), so `tienda_cliente` is no longer the single
      # source of truth. The `asignar_tienda_cliente` before-save callback
      # keeps `visualizando_tienda` populated for cliente users; we fall back
      # to `tienda_cliente` only for legacy rows where the callback never ran.
      visualizando_tienda || tienda_cliente
    end
    memoize :tienda_activa

    # Tiendas where this user is allowed to log in.
    # - cliente users: HABTM through cliente.tiendas, filtered by permitir_login_clientes
    # - admin/operador: tiendas joined via usuarios_tiendas (no flag check)
    def tiendas_disponibles
      if cliente?
        return Tiendas::Tienda.none unless cuenta&.cliente

        cuenta.cliente.tiendas.where(permitir_login_clientes: true)
      else
        tiendas
      end
    end

    def puede_loguearse_en?(tienda)
      return false if tienda.nil?

      tiendas_disponibles.exists?(id: tienda.id)
    end

    def local_activo
      visualizando_local || local
    end

    def password_expired?
      password_expires_at.past?
    end

    def ability
      @ability ||= Ability.new(self)
    end

    def self.sistema
      find_by login: 'sistema'
    end

    def sistema?
      login == 'sistema'
    end

    def es_administrador_de_empresa?
      cumple_rol?(:administrador_empresa)
    end

    def email_principal
      email.split(',').first.to_s.strip.presence if email
    end

    def tipo_id=(nro)
      self.tipo_usuario_id = nro.to_i if new_record?
    end

    def tipo_id
      tipo_usuario_id
    end

    private

    def prevent_super_admin_deletion
      return unless id == 1

      errors.add(:base, 'No se puede eliminar el super administrador')
      throw(:abort)
    end

    def prevent_super_admin_discontinuation
      return unless id == 1 && discontinued_at_changed? && discontinued_at.present?

      errors.add(:base, 'No se puede desactivar el super administrador')
      throw(:abort)
    end

    def asignar_tienda
      if cliente? && cliente
        # tienda_cliente is the legacy FK used as a fallback and for validation.
        # Always keep it aligned to the first tienda for the cliente (legacy behaviour).
        self.tienda_cliente = cliente.tienda if tienda_cliente.blank?

        # visualizando_tienda is what drives tienda_activa at request time.
        # For multi-tienda clientes we must NOT overwrite it on every save —
        # doing so resets any tienda switch the user made via cambiar_tienda_activa.
        # Only assign it when it is blank or when it points to a tienda the
        # cliente no longer has access to (e.g. after tienda unlink).
        self.visualizando_tienda = cliente.tienda if visualizando_tienda.blank? || !puede_loguearse_en?(visualizando_tienda)
      elsif !visualizando_tienda && tiendas.first
        self.visualizando_tienda = tiendas.first
      end
    end

    def solo_una_foto
      errors.add :base, 'Sólo puede subir una (1) foto de perfil.' if documentos.size > 1
    end

    def encrypt_password
      self.password_expires_at = 1.day.ago if solicitar_cambio_contrasena == '1'
      return if password.blank?

      self.salt = Digest::SHA1.hexdigest("--#{Time.current}--#{login}--")
      self.crypted_password = encrypt(password)
    end

    def password_required?
      crypted_password.blank? || password.present?
    end

    def validar_cuenta
      return unless tipo_usuario_id.to_i == 1

      return if cuenta

      errors.add :cuenta,
                 "Es obligatoria la asignación de una 'Cuenta de Cliente' a los usuarios de este tipo."
    end

    def validar_local
      return unless tipo_usuario_id.to_i != 1

      errors.add :local, 'Es obligatoria la asignación de un local.' if !local && visualizando_tienda&.multiple_locales
    end

    def rectificar_roles
      if cuenta && administrador_de_empresa.present?
        self.roles = administrador_de_empresa == '1' ? [:administrador_empresa] : [:comprador]
      end
      rols = roles
      if cuenta && rols.any? { |x| Rol.configurables_admin.include?(x) }
        self.roles = rols.reject { |x| Rol.configurables_admin.include?(x) }
      elsif !cuenta && rols.any? { |x| Rol.configurables_admin.exclude?(x) }
        self.roles = rols.select { |x| Rol.configurables_admin.include?(x) }
      end
    end
  end
end
