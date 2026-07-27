require 'barby/barcode/code_39'
require 'barby/barcode/ean_13'
require 'barby/barcode/code_25_interleaved'
require 'barby/outputter/png_outputter'
require 'barby/outputter/svg_outputter'

module Infraestructura
  class BarcodesController < ApplicationController
    skip_before_action :login_required
    skip_authorization_check

    def new
      barcode = barcode_class.new(params[:data]).to_png(height: 30, xdim: 2, margin: 0)
      send_data barcode, type: 'image/png', disposition: 'inline'
    end

    private

    def barcode_class
      case params[:type]
      when 'Int2of5'
        Barby::Code25Interleaved
      when 'ean13'
        Barby::EAN13
      else
        Barby::Code39
      end
    end
  end
end
