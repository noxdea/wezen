# frozen_string_literal: true

module Wezen
  module APNG
    module_function

    def encode(animation, compression: 9, diff: true)
      raise ArgumentError, "animation must contain at least one frame" if animation.size.zero?
      frames = animation.each.to_a
      sequence = 0
      output = PNG::SIGNATURE.dup
      output << PNG.chunk("IHDR", [animation.width, animation.height, 8, 6, 0, 0, 0].pack("NNC5"))
      output << PNG.chunk("acTL", [frames.length, animation.loop].pack("N2"))
      previous = nil
      frames.each_with_index do |frame, index|
        rect, pixels, blend = rectangle(animation, previous, frame.rgba, diff && index.positive?)
        delay_num, delay_den = delay(frame.delay_ms)
        output << PNG.chunk("fcTL", [sequence, rect[2], rect[3], rect[0], rect[1], delay_num, delay_den, 0, blend].pack("N5n2C2"))
        sequence += 1
        scanlines = scanlines(pixels, rect[2], rect[3])
        compressed = Zlib::Deflate.deflate(scanlines, Integer(compression))
        if index.zero?
          output << PNG.chunk("IDAT", compressed)
        else
          output << PNG.chunk("fdAT", [sequence].pack("N") + compressed)
          sequence += 1
        end
        previous = frame.rgba
      end
      output << PNG.chunk("IEND", "".b)
    end

    def write(path, animation, **options)
      File.binwrite(path, encode(animation, **options))
      path
    end

    def rectangle(animation, previous, current, use_diff)
      return [[0, 0, animation.width, animation.height], current, 0] unless use_diff && previous

      bounds = Image.diff_bounds(previous, current, animation.width, animation.height)
      return [[0, 0, 1, 1], "\0\0\0\0".b, 1] unless bounds

      x, y, width, height = bounds
      patch = Image.crop(current, animation.width, animation.height, bounds)
      # APNG source blending is exact for the opaque UI pixels this encoder targets.
      # Fall back to a complete frame when alpha would make source-over lossy.
      if patch.bytes.each_slice(4).any? { |pixel| pixel[3] != 255 }
        [[0, 0, animation.width, animation.height], current, 0]
      else
        [[x, y, width, height], patch, 1]
      end
    end

    def scanlines(rgba, width, height)
      raw = String.new(encoding: Encoding::BINARY)
      height.times { |row| raw << "\0" << rgba.byteslice(row * width * 4, width * 4) }
      raw
    end

    def delay(milliseconds)
      milliseconds = Integer(milliseconds)
      return [0, 1000] if milliseconds.zero?
      denominator = 1000
      numerator = milliseconds
      common = numerator.gcd(denominator)
      [numerator / common, denominator / common]
    end
    private_class_method :rectangle, :scanlines, :delay
  end
end
