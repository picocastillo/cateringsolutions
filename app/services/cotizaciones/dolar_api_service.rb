require 'net/http'
require 'json'

module Cotizaciones
  class DolarApiService
    MAX_RETRIES = 5

    # Fetches current official rate from dolarapi.com
    # Returns { fecha:, precio_venta:, precio_compra:, fuente: } or nil
    def fetch_actual
      last_error = nil

      MAX_RETRIES.times do |attempt|
        uri = URI('https://dolarapi.com/v1/dolares/oficial')
        response = Net::HTTP.get_response(uri)

        unless response.is_a?(Net::HTTPSuccess)
          last_error = "HTTP #{response.code}"
          wait = 2**attempt
          Rails.logger.warn "Cotización dólar: intento #{attempt + 1}/#{MAX_RETRIES} falló (#{last_error}), reintentando en #{wait}s..."
          sleep(wait)
          next
        end

        data = JSON.parse(response.body)
        precio_venta = data['venta']
        precio_compra = data['compra']

        if precio_venta.nil? || precio_venta.to_f <= 0
          last_error = "Cotización inválida: #{data.inspect}"
          wait = 2**attempt
          Rails.logger.warn "Cotización dólar: intento #{attempt + 1}/#{MAX_RETRIES} falló (#{last_error}), reintentando en #{wait}s..."
          sleep(wait)
          next
        end

        return {
          fecha: Date.current,
          precio_venta: precio_venta.to_f,
          precio_compra: precio_compra&.to_f,
          fuente: 'oficial'
        }
      end

      error = StandardError.new("Error al obtener cotización del dólar después de #{MAX_RETRIES} intentos: #{last_error}")
      Notify.exception(error, api: 'dolarapi.com', intentos: MAX_RETRIES)
      nil
    end

    # Fetches historical rate for a single date from api.argentinadatos.com
    # Returns { fecha:, precio_venta:, precio_compra:, fuente: } or nil
    def fetch_historico(fecha)
      fecha = fecha.to_date if fecha.respond_to?(:to_date)
      url = "https://api.argentinadatos.com/v1/cotizaciones/dolares/oficial/#{fecha.strftime('%Y/%m/%d')}/"

      uri = URI(url)
      response = Net::HTTP.get_response(uri)

      unless response.is_a?(Net::HTTPSuccess)
        error = StandardError.new("Cotización dólar histórica #{fecha}: HTTP #{response.code}")
        Notify.exception(error, api: 'argentinadatos.com', fecha: fecha)
        return nil
      end

      data = JSON.parse(response.body)
      precio_venta = data['venta']

      if precio_venta.nil? || precio_venta.to_f <= 0
        Rails.logger.warn "Cotización dólar histórica #{fecha}: cotización inválida: #{data.inspect}"
        return nil
      end

      {
        fecha: fecha,
        precio_venta: precio_venta.to_f,
        precio_compra: data['compra']&.to_f,
        fuente: 'oficial'
      }
    end

    # Fetches a range of historical rates from api.argentinadatos.com
    # Returns array of { fecha:, precio_venta:, precio_compra:, fuente: }
    def fetch_rango(from_date, to_date)
      from_date = from_date.to_date if from_date.respond_to?(:to_date)
      to_date = to_date.to_date if to_date.respond_to?(:to_date)

      url = 'https://api.argentinadatos.com/v1/cotizaciones/dolares/oficial/'
      uri = URI(url)

      response = Net::HTTP.get_response(uri)

      unless response.is_a?(Net::HTTPSuccess)
        error = StandardError.new("Cotización dólar rango: HTTP #{response.code}")
        Notify.exception(error, api: 'argentinadatos.com')
        return nil
      end

      datos = JSON.parse(response.body)

      unless datos.is_a?(Array)
        Rails.logger.error "Cotización dólar rango: respuesta inesperada: #{datos.class}"
        return nil
      end

      datos.filter_map do |entry|
        fecha = begin
          Date.parse(entry['fecha'])
        rescue StandardError
          next
        end
        next unless fecha.between?(from_date, to_date)

        precio_venta = entry['venta']
        next if precio_venta.nil? || precio_venta.to_f <= 0

        {
          fecha: fecha,
          precio_venta: precio_venta.to_f,
          precio_compra: entry['compra']&.to_f,
          fuente: 'oficial'
        }
      end
    rescue JSON::ParserError => e
      Rails.logger.error "Cotización dólar rango: JSON parse error: #{e.message}"
      nil
    end
  end
end
