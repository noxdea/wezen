# frozen_string_literal: true

module Wezen
  module Image
    module_function

    def scale(rgba, width, height, to_width:, to_height:)
      width = Integer(width); height = Integer(height)
      to_width = Integer(to_width); to_height = Integer(to_height)
      validate!(rgba, width, height)
      raise ArgumentError, "invalid target dimensions" unless to_width.positive? && to_height.positive?

      output = String.new(capacity: to_width * to_height * 4, encoding: Encoding::BINARY)
      to_height.times do |dy|
        y0 = dy * height.fdiv(to_height); y1 = (dy + 1) * height.fdiv(to_height)
        to_width.times do |dx|
          x0 = dx * width.fdiv(to_width); x1 = (dx + 1) * width.fdiv(to_width)
          sx0 = x0.floor; sx1 = [x1.ceil, width].min
          sy0 = y0.floor; sy1 = [y1.ceil, height].min
          count = 0; sum = [0, 0, 0, 0]
          (sy0...sy1).each do |sy|
            (sx0...sx1).each do |sx|
              pixel = rgba.byteslice((sy * width + sx) * 4, 4).bytes
              4.times { |channel| sum[channel] += pixel[channel] }
              count += 1
            end
          end
          output << sum.map { |value| (value.to_f / count).round }.pack("C4")
        end
      end
      output
    end

    def crop(rgba, width, height, bounds)
      x, y, crop_width, crop_height = self.bounds(bounds)
      validate!(rgba, width, height)
      raise ArgumentError, "crop is outside image" unless x >= 0 && y >= 0 && crop_width.positive? && crop_height.positive? && x + crop_width <= width && y + crop_height <= height

      output = String.new(capacity: crop_width * crop_height * 4, encoding: Encoding::BINARY)
      crop_height.times { |row| output << rgba.byteslice(((y + row) * width + x) * 4, crop_width * 4) }
      output
    end

    def blend(dst, dst_width, src, src_width, src_height, x:, y:, opacity: 1.0)
      dst_width = Integer(dst_width); src_width = Integer(src_width); src_height = Integer(src_height)
      destination = String(dst).b.dup
      raise ArgumentError, "invalid source image" unless src.bytesize == src_width * src_height * 4
      raise ArgumentError, "invalid destination image" unless destination.bytesize % 4 == 0 && dst_width.positive?
      dst_height = destination.bytesize / 4 / dst_width
      alpha = Float(opacity)
      raise ArgumentError, "opacity must be between 0 and 1" unless alpha.between?(0.0, 1.0)

      src_height.times do |sy|
        dy = Integer(y) + sy
        next unless dy.between?(0, dst_height - 1)
        src_width.times do |sx|
          dx = Integer(x) + sx
          next unless dx.between?(0, dst_width - 1)
          si = (sy * src_width + sx) * 4; di = (dy * dst_width + dx) * 4
          sr, sg, sb, sa = src.byteslice(si, 4).bytes
          sa = (sa * alpha).round
          dr, dg, db, da = destination.byteslice(di, 4).bytes
          source_alpha = sa / 255.0; destination_alpha = da / 255.0
          out_alpha = source_alpha + destination_alpha * (1.0 - source_alpha)
          if out_alpha.zero?
            destination[di, 4] = "\0\0\0\0".b
          else
            destination[di, 4] = [
              ((sr * source_alpha + dr * destination_alpha * (1.0 - source_alpha)) / out_alpha).round,
              ((sg * source_alpha + dg * destination_alpha * (1.0 - source_alpha)) / out_alpha).round,
              ((sb * source_alpha + db * destination_alpha * (1.0 - source_alpha)) / out_alpha).round,
              (out_alpha * 255).round
            ].pack("C4")
          end
        end
      end
      dst.replace(destination) if dst.respond_to?(:replace) && !dst.frozen?
      destination
    end

    def diff_bounds(previous, current, width, height)
      validate!(previous, width, height); validate!(current, width, height)
      min_x = width; min_y = height; max_x = -1; max_y = -1
      (0...(width * height)).each do |index|
        next if previous.byteslice(index * 4, 4) == current.byteslice(index * 4, 4)
        x = index % width; y = index / width
        min_x = x if x < min_x; min_y = y if y < min_y; max_x = x if x > max_x; max_y = y if y > max_y
      end
      max_x.negative? ? nil : [min_x, min_y, max_x - min_x + 1, max_y - min_y + 1]
    end

    def bounds(value)
      values = value.respond_to?(:to_a) ? value.to_a : value
      raise ArgumentError, "bounds must contain x, y, width, height" unless values && values.length == 4
      values.map { |item| Integer(item) }
    end

    def validate!(rgba, width, height)
      raise ArgumentError, "invalid dimensions" unless Integer(width).positive? && Integer(height).positive?
      raise ArgumentError, "invalid RGBA pixels" unless rgba.bytesize == width * height * 4
    end
    private_class_method :validate!
  end
end
