# Fix Flying Saucer PDF deadlock in development mode with Puma.
#
# Flying Saucer (Java) fetches resources (CSS, images, barcodes) via HTTP
# back to the same server. In development mode, Rails' autoload interlock
# (ActiveSupport::Dependencies.interlock) wraps each request with a shared lock.
# When the PDF thread blocks on the Java system call while holding this lock,
# the incoming barcode/asset requests can't proceed because the Reloader's
# check! needs an exclusive lock → deadlock.
#
# permit_concurrent_loads temporarily releases the shared lock so other
# threads can handle the resource requests.
#
# Also restores File.exists? (removed in Ruby 3.2+) needed by the gem.
unless File.respond_to?(:exists?)
  class File
    class << self
      alias exists? exist?
    end
  end
end

module ActsAsFlyingSaucer
  class Xhtml2Pdf
    class << self
      alias write_pdf_without_concurrency write_pdf

      def write_pdf(options)
        ActiveSupport::Dependencies.interlock.permit_concurrent_loads do
          write_pdf_without_concurrency(options)
        end
      end
    end
  end
end
