require 'barby/barcode/code_39'
require 'barby/barcode/ean_13'
require 'barby/barcode/code_25_interleaved'
require 'barby/outputter/png_outputter'
require 'digest/md5'

module PdfHelper
  # Inline CSS from asset pipeline as a <style> block (eliminates HTTP fetch by Java renderer)
  def inline_stylesheet(asset_name)
    asset = Rails.application.assets&.find_asset(asset_name)
    css = if asset
            asset.to_s
          else
            # Fallback: read from precompiled manifest in production
            manifest_path = Rails.public_path.join('assets/.sprockets-manifest*.json')
            manifest_files = Dir.glob(manifest_path)
            if manifest_files.any?
              manifest = JSON.parse(File.read(manifest_files.first))
              digest_path = manifest.dig('assets', asset_name)
              Rails.public_path.join('assets', digest_path).read if digest_path
            end
          end
    tag = "<style type=\"text/css\">#{css}</style>" if css.present?
    tag&.html_safe
  end

  # Generate barcode PNG and write to temp file, return file:// img tag.
  # Flying Saucer R8 doesn't support data: URIs, so we use local file:// paths.
  def inline_barcode_image(data, type: nil, **img_options)
    return '' if data.blank?

    barcode_class = case type.to_s
                    when 'ean13' then Barby::EAN13
                    when 'Int2of5' then Barby::Code25Interleaved
                    else Barby::Code39
                    end

    png_data = barcode_class.new(data.to_s).to_png(height: 30, xdim: 2, margin: 0)
    file_url = write_tmp_image(png_data, "barcode_#{Digest::MD5.hexdigest(data.to_s + type.to_s)}.png")

    attrs = img_options.map { |k, v| "#{k}=\"#{ERB::Util.html_escape(v)}\"" }.join(' ')
    "<img src=\"#{file_url}\" #{attrs} />".html_safe
  end

  # Reference a static image from public/ via file:// URL
  def inline_public_image(path, **img_options)
    full_path = Rails.public_path.join(path.to_s.sub(%r{\A/}, ''))
    return image_tag(path, **img_options) unless File.exist?(full_path)

    file_url = "file://#{full_path}"
    attrs = img_options.map { |k, v| "#{k}=\"#{ERB::Util.html_escape(v)}\"" }.join(' ')
    "<img src=\"#{file_url}\" #{attrs} />".html_safe
  end

  # Reference a Paperclip attachment via file:// URL
  def inline_paperclip_image(attachment, **img_options)
    return '' unless attachment&.exists?

    file_path = attachment.path
    return image_tag(attachment.url, **img_options) unless file_path && File.exist?(file_path)

    file_url = "file://#{file_path}"
    attrs = img_options.map { |k, v| "#{k}=\"#{ERB::Util.html_escape(v)}\"" }.join(' ')
    "<img src=\"#{file_url}\" #{attrs} />".html_safe
  end

  private

  def write_tmp_image(binary_data, filename)
    tmp_dir = ActsAsFlyingSaucer::Config.options[:tmp_path] || '/tmp'
    path = File.join(tmp_dir, filename)
    File.binwrite(path, binary_data) unless File.exist?(path)
    "file://#{path}"
  end
end
