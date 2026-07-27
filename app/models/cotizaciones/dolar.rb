module Cotizaciones
  class Dolar < ApplicationRecord
    self.table_name = 'cotizaciones_dolar'

    validates :fecha, presence: true, uniqueness: true
    validates :precio_venta, presence: true, numericality: { greater_than: 0 }
    validates :fuente, presence: true

    # Returns the precio_venta for a given date.
    # Falls back to the most recent previous day if not found.
    # For Date.today, enqueues a background job to fetch if missing.
    def self.precio_para_fecha(fecha)
      fecha = fecha.to_date if fecha.respond_to?(:to_date)
      registro = find_by(fecha: fecha)
      return registro.precio_venta if registro

      # Today is missing: enqueue background fetch and return fallback
      Cotizaciones::ActualizarDolarJob.perform_later(fecha.to_s) if fecha == Date.current

      # Fallback: latest available rate (pedidos can be for future dates)
      anterior = order(fecha: :desc).first
      anterior&.precio_venta
    end

    # Shortcut for today's rate
    def self.precio_hoy
      precio_para_fecha(Date.current)
    end

    # Fetch from API and upsert for a given date (defaults to today)
    def self.actualizar!(fecha = Date.current)
      fecha = fecha.to_date if fecha.respond_to?(:to_date)

      # Skip if already exists for today (avoids redundant API calls)
      return find_by(fecha: fecha) if exists?(fecha: fecha) && fecha == Date.current

      service = Cotizaciones::DolarApiService.new
      data = if fecha == Date.current
               service.fetch_actual
             else
               service.fetch_historico(fecha)
             end

      return nil unless data

      registro = find_or_initialize_by(fecha: fecha)
      registro.update!(
        precio_venta: data[:precio_venta],
        precio_compra: data[:precio_compra],
        fuente: data[:fuente] || 'oficial'
      )
      registro
    end

    # Backfill historical rates from a start date to today
    def self.backfill!(from_date:, to_date: Date.current)
      from_date = from_date.to_date if from_date.respond_to?(:to_date)
      to_date = to_date.to_date if to_date.respond_to?(:to_date)

      existing_dates = where(fecha: from_date..to_date).pluck(:fecha).to_set

      service = Cotizaciones::DolarApiService.new
      datos = service.fetch_rango(from_date, to_date)
      return 0 unless datos

      count = 0
      datos.each do |data|
        fecha = data[:fecha].to_date
        next if existing_dates.include?(fecha)

        create!(
          fecha: fecha,
          precio_venta: data[:precio_venta],
          precio_compra: data[:precio_compra],
          fuente: data[:fuente] || 'oficial'
        )
        count += 1
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn "Cotización dólar backfill #{fecha}: #{e.message}"
      end
      count
    end
  end
end
