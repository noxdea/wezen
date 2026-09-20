# frozen_string_literal: true

module Wezen
  module Quantize
    module_function

    MAX_PALETTE_SAMPLES = 32_768

    def palette(animation, colors:, method: :median_cut)
      raise ArgumentError, "unsupported quantizer: #{method}" unless %i[median_cut octree].include?(method)
      limit = Integer(colors)
      raise ArgumentError, "colors must be between 2 and 256" unless limit.between?(2, 256)
      total_pixels = animation.width * animation.height * animation.size
      pixels, transparent = if total_pixels <= MAX_PALETTE_SAMPLES
        [animation.each.flat_map { |frame| frame.rgba.bytes.each_slice(4).reject { |pixel| pixel[3] < 128 }.map { |pixel| pixel[0, 3] } },
          animation.each.any? { |frame| frame.rgba.bytes.each_slice(4).any? { |pixel| pixel[3] < 128 } }]
      else
        sample_pixels(animation, total_pixels)
      end
      pixels = [[0, 0, 0]] if pixels.empty?
      opaque_limit = transparent ? limit - 1 : limit
      colors_out = median_cut(pixels, opaque_limit)
      if transparent
        colors_out = [[0, 0, 0], *colors_out]
        Palette.new(colors_out, 0)
      else
        Palette.new(colors_out, nil)
      end
    end

    def sample_pixels(animation, total_pixels)
      # ponytail: cap median-cut input at 32K samples; replace with a weighted histogram if palette fidelity matters.
      step = (total_pixels.fdiv(MAX_PALETTE_SAMPLES)).ceil
      pixels = []
      transparent = false
      pixel_index = 0
      next_sample = 0
      animation.each do |frame|
        rgba = frame.rgba
        offset = 0
        while offset < rgba.bytesize
          alpha = rgba.getbyte(offset + 3)
          transparent ||= alpha < 128
          if pixel_index == next_sample
            pixels << [rgba.getbyte(offset), rgba.getbyte(offset + 1), rgba.getbyte(offset + 2)] if alpha >= 128
            next_sample += step
          end
          pixel_index += 1
          offset += 4
        end
      end
      [pixels, transparent]
    end

    def apply(rgba, palette, width: nil, height: nil, dither: :floyd_steinberg)
      raise ArgumentError, "unknown dither: #{dither}" unless %i[none bayer floyd_steinberg].include?(dither)
      raise ArgumentError, "palette must be a Wezen::Palette" unless palette.respond_to?(:colors)
      width ||= rgba.bytesize / 4
      height ||= 1
      apply_with_size(rgba, palette, width: width, height: height, dither: dither)
    end

    def apply_with_size(rgba, palette, width:, height:, dither: :floyd_steinberg)
      width = Integer(width)
      height = Integer(height)
      raise ArgumentError, "invalid RGBA pixels" unless rgba.bytesize == width * height * 4
      return apply_without_error(rgba, palette, width, height, dither) unless dither == :floyd_steinberg

      colors = palette.colors
      output = String.new(capacity: width * height, encoding: Encoding::BINARY)
      errors = Array.new(width * 3, 0.0)
      next_errors = Array.new(width * 3, 0.0)
      rgba.bytes.each_slice(4).with_index do |pixel, index|
        x = index % width; y = index / width
        alpha = pixel[3]
        if alpha < 128 && palette.transparent_index
          output << palette.transparent_index
          next
        end
        adjusted = pixel[0, 3].map.with_index do |channel, component|
          value = channel.to_f
          value += errors[x * 3 + component] if dither == :floyd_steinberg
          if dither == :bayer
            value += bayer(x, y) * 16 - 8
          end
          value.clamp(0, 255)
        end
        index_color = nearest(adjusted, colors, palette.transparent_index)
        output << index_color
        next unless dither == :floyd_steinberg

        chosen = colors[index_color]
        delta = 3.times.map { |channel| adjusted[channel] - chosen[channel] }
        distribute(errors, next_errors, x, width, delta)
        if x == width - 1
          errors = next_errors
          next_errors = Array.new(width * 3, 0.0)
        end
      end
      output
    end

    def apply_without_error(rgba, palette, width, height, dither)
      colors = palette.colors
      transparent_index = palette.transparent_index
      output = String.new(capacity: width * height, encoding: Encoding::BINARY)
      cache = {}
      offset = 0
      x = 0
      y = 0
      while offset < rgba.bytesize
        alpha = rgba.getbyte(offset + 3)
        if alpha < 128 && transparent_index
          output << transparent_index
        else
          red = rgba.getbyte(offset)
          green = rgba.getbyte(offset + 1)
          blue = rgba.getbyte(offset + 2)
          if dither == :bayer
            adjustment = (bayer(x, y) * 16 - 8).to_i
            red = red + adjustment
            green = green + adjustment
            blue = blue + adjustment
            red = 0 if red < 0
            green = 0 if green < 0
            blue = 0 if blue < 0
            red = 255 if red > 255
            green = 255 if green > 255
            blue = 255 if blue > 255
          end
          key = (red << 16) | (green << 8) | blue
          cache[key] ||= nearest_rgb(red, green, blue, colors, transparent_index)
          output << cache[key]
        end
        offset += 4
        x += 1
        if x == width
          x = 0
          y += 1
        end
      end
      output
    end

    def median_cut(pixels, limit)
      boxes = [pixels.sort_by { |pixel| pixel[0] * 65_536 + pixel[1] * 256 + pixel[2] }]
      while boxes.length < limit
        candidate = boxes.each_with_index.max_by do |box, index|
          ranges = 3.times.map { |axis| box.map { |pixel| pixel[axis] }.then { |values| values.max - values.min } }
          [box.length, *ranges, -index]
        end
        break unless candidate
        box, index = candidate
        axis = 3.times.max_by { |item| [box.map { |pixel| pixel[item] }.then { |values| values.max - values.min }, -item] }
        ordered = box.sort_by { |pixel| [pixel[axis], pixel[0], pixel[1], pixel[2]] }
        cut = [ordered.length / 2, 1].max
        break if cut >= ordered.length
        boxes[index] = ordered[0, cut]
        boxes << ordered[cut..]
      end
      boxes.map do |box|
        box.transpose.map { |channel| (channel.sum.fdiv(channel.length)).round }
      end.sort
    end

    def nearest(pixel, colors, transparent_index)
      nearest_rgb(pixel[0], pixel[1], pixel[2], colors, transparent_index)
    end

    def nearest_rgb(red, green, blue, colors, transparent_index)
      best_index = nil
      best_distance = nil
      colors.each_with_index do |color, index|
        next if index == transparent_index

        distance = (red - color[0])**2 + (green - color[1])**2 + (blue - color[2])**2
        if best_distance.nil? || distance < best_distance
          best_distance = distance
          best_index = index
        end
      end
      best_index
    end

    def bayer(x, y)
      [[0, 8], [12, 4]][y % 2][x % 2] / 16.0
    end

    def distribute(errors, next_errors, x, width, delta)
      add = ->(array, column, factor) { 3.times { |channel| array[column * 3 + channel] += delta[channel] * factor } if column.between?(0, width - 1) }
      add.call(errors, x + 1, 7.0 / 16)
      add.call(next_errors, x - 1, 3.0 / 16)
      add.call(next_errors, x, 5.0 / 16)
      add.call(next_errors, x + 1, 1.0 / 16)
    end
    private_class_method :sample_pixels, :median_cut, :nearest, :nearest_rgb, :apply_without_error, :bayer, :distribute
  end
end
