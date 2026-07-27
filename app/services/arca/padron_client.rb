module Arca
  # Queries AFIP / ARCA "Constancia de Inscripción" (ws_sr_constancia_inscripcion / A5)
  # via the `afipws` gem (https://github.com/eeng/afipws).
  #
  # Required ENV vars:
  #   AFIP_CUIT  — your company CUIT (e.g. "20123456789")
  #   AFIP_KEY   — PEM private key content
  #   AFIP_CERT  — PEM certificate content
  #   AFIP_ENV   — "development" | "production" (default: "development")
  #
  # When any of AFIP_CUIT / AFIP_KEY / AFIP_CERT is absent, returns nil so
  # the user simply fills in the form fields manually.
  class PadronClient
    def self.fetch(cuit)
      new(cuit).fetch
    end

    def initialize(cuit)
      @cuit = cuit.to_s.gsub(/\D/, '')
    end

    def fetch
      return nil unless @cuit.length == 11
      return nil unless ENV['AFIP_CUIT'].present? && ENV['AFIP_KEY'].present? && ENV['AFIP_CERT'].present?

      ws = Afipws::WSConstanciaInscripcion.new(
        env: ENV.fetch('AFIP_ENV', 'development').to_sym,
        cuit: ENV.fetch('AFIP_CUIT', nil),
        key: ENV.fetch('AFIP_KEY', nil),
        cert: ENV.fetch('AFIP_CERT', nil)
      )
      normalize(ws.get_persona(@cuit))
    rescue Afipws::Error, StandardError => e
      Notify.exception(e, origen: 'Arca::PadronClient', cuit: @cuit)
      nil
    end

    private

    def normalize(raw)
      return nil if raw.blank?

      generales = raw[:datos_generales]
      return nil if generales.blank?

      {
        nombre: extract_nombre(generales),
        domicilio: extract_domicilio(generales[:domicilio_fiscal]),
        tipo_persona: generales[:tipo_persona],
        estado: generales[:estado_clave],
        raw: raw
      }.compact
    end

    def extract_nombre(generales)
      razon = generales[:razon_social]
      return razon.strip if razon.present?

      [generales[:apellido], generales[:nombre]].compact.map(&:strip).reject(&:empty?).join(' ').presence
    end

    def extract_domicilio(dom)
      return nil unless dom.is_a?(Hash)

      [
        dom[:direccion],
        dom[:localidad],
        [dom[:descripcion_provincia], dom[:cod_postal] ? "(#{dom[:cod_postal]})" : nil].compact.reject(&:empty?).join(' ').presence
      ].compact.reject { |v| v.to_s.strip.empty? }.join(', ').presence
    end
  end
end
