# frozen_string_literal: true

module Tiendas
  # Resolves which `tiendas.dominio` a request host belongs to.
  #
  # Production apex hosts match `request.domain(2)` as before. Staging hosts such
  # as `cateringsolutions.trackerdev.com.ar` are mapped via
  # `config/tienda_host_aliases.yml` so DB `dominio` (and asset filenames) stay
  # on the production values.
  class HostResolver
    DEFAULT_TLD_LENGTH = 2

    class << self
      def normalize(host)
        host.to_s.downcase.sub(/\Awww\./, '')
      end

      def aliases
        @aliases ||= load_aliases
      end

      def reset_aliases!
        @aliases = nil
      end

      def canonical_dominio(host, tld_length: DEFAULT_TLD_LENGTH)
        normalized = normalize(host)
        return nil if normalized.blank?

        aliases[normalized] || extract_domain(normalized, tld_length) || normalized
      end

      def matches?(host, tienda_dominio, tld_length: DEFAULT_TLD_LENGTH)
        return false if tienda_dominio.blank?

        expected = tienda_dominio.to_s.downcase
        normalized = normalize(host)
        return false if normalized.blank?

        normalized == expected ||
          aliases[normalized] == expected ||
          extract_domain(normalized, tld_length) == expected ||
          canonical_dominio(normalized, tld_length: tld_length) == expected
      end

      def find_tienda(host, tld_length: DEFAULT_TLD_LENGTH)
        normalized = normalize(host)
        return Tienda.first if normalized.blank?

        candidates = [
          normalized,
          aliases[normalized],
          extract_domain(normalized, tld_length)
        ].compact.map(&:downcase).uniq

        candidates.each do |dominio|
          tienda = Tienda.find_by(dominio: dominio)
          return tienda if tienda
        end

        Tienda.first
      end

      def public_host(host, tienda_dominio, tld_length: DEFAULT_TLD_LENGTH)
        normalized = normalize(host)
        return tienda_dominio.to_s if normalized.blank?

        matches?(normalized, tienda_dominio, tld_length: tld_length) ? normalized : tienda_dominio.to_s
      end

      private

      def extract_domain(host, tld_length)
        ActionDispatch::Http::URL.extract_domain(host.to_s, tld_length)
      rescue StandardError
        nil
      end

      def load_aliases
        path = ENV.fetch('TIENDA_HOST_ALIASES_FILE', Rails.root.join('config/tienda_host_aliases.yml').to_s)
        return {} unless File.file?(path)

        raw = YAML.load_file(path) || {}
        raw.each_with_object({}) do |(from, to), memo|
          next if from.blank? || to.blank?

          memo[normalize(from)] = normalize(to)
        end
      end
    end
  end
end
