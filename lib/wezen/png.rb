# frozen_string_literal: true

module Wezen
  module PNG
    SIGNATURE = "\x89PNG\r\n\x1a\n".b.freeze
    module_function

    def encode(width, height, rgba, compression: 9)
      validate(width, height, rgba)
      scanlines = String.new(encoding: Encoding::BINARY)
      height.times { |row| scanlines << "\0" << rgba.byteslice(row * width * 4, width * 4) }
      SIGNATURE + chunk("IHDR", [width, height, 8, 6, 0, 0, 0].pack("NNC5")) +
        chunk("IDAT", Zlib::Deflate.deflate(scanlines, Integer(compression))) + chunk("IEND", "".b)
    end

    def write(path, width, height, rgba, **options)
      File.binwrite(path, encode(width, height, rgba, **options))
      path
    end

    def chunk(kind, data)
      [data.bytesize].pack("N") + kind + data + [Zlib.crc32(kind + data)].pack("N")
    end

    def validate(width, height, rgba)
      raise ArgumentError, "invalid image dimensions" unless width.to_i.positive? && height.to_i.positive?
      raise ArgumentError, "invalid RGBA pixels" unless rgba.bytesize == width * height * 4
    end
    private_class_method :validate
  end
end
