# frozen_string_literal: true

module Wezen
  module GIF
    module_function

    def encode(animation, colors: 256, palette: :global, dither: :floyd_steinberg, diff: true)
      raise ArgumentError, "animation must contain at least one frame" if animation.size.zero?
      raise ArgumentError, "palette must be :global, :adaptive, or a Palette" unless palette == :global || palette == :adaptive || palette.respond_to?(:colors)
      limit = Integer(colors)
      raise ArgumentError, "colors must be between 2 and 256" unless limit.between?(2, 256)

      source_palette = palette.respond_to?(:colors) ? palette : Quantize.palette(animation, colors: limit)
      needs_transparency = diff && animation.each_cons(2).any? { |left, right| left.rgba == right.rgba }
      source_palette = reserve_transparency(source_palette, limit) if needs_transparency && source_palette.transparent_index.nil?
      table_size = [source_palette.colors.length, 2].max
      bits = [[Math.log2(table_size).ceil, 1].max, 8].min
      table_size = 1 << bits
      colors_table = source_palette.colors + Array.new(table_size - source_palette.colors.length, [0, 0, 0])
      output = "GIF89a".b
      output << [animation.width, animation.height, 0x80 | ((bits - 1) << 4) | (bits - 1), 0, 0].pack("vvC3")
      colors_table.each { |color| output << color.pack("C3") }
      output << loop_extension(animation.loop)

      previous = nil
      animation.each.with_index do |frame, index|
        rect, patch_rgba = if index.zero? || !diff || previous.nil?
          [[0, 0, animation.width, animation.height], frame.rgba]
        else
          bounds = Image.diff_bounds(previous, frame.rgba, animation.width, animation.height)
          if bounds
            [bounds, Image.crop(frame.rgba, animation.width, animation.height, bounds)]
          else
            [[0, 0, 1, 1], nil]
          end
        end
        patch = if patch_rgba
          width = rect[2]
          height = rect[3]
          transparent = source_palette.transparent_index && patch_rgba.bytes.each_slice(4).any? { |pixel| pixel[3] < 128 }
          Quantize.apply_with_size(patch_rgba, source_palette, width: width, height: height, dither: dither)
        else
          transparent = source_palette.transparent_index
          patch_rgba
        end
        output << graphic_control(frame.delay_ms, transparent ? source_palette.transparent_index : nil)
        output << image_descriptor(rect, bits)
        output << sub_blocks(lzw(patch, [bits, 2].max), [bits, 2].max)
        previous = frame.rgba
      end
      output << "\x3B".b
    end

    def write(path, animation, **options)
      File.binwrite(path, encode(animation, **options))
      path
    end

    def reserve_transparency(palette, limit)
      opaque = palette.colors.reject.with_index { |_color, index| index == palette.transparent_index }
      Palette.new([[0, 0, 0], *opaque.first(limit - 1)], 0)
    end

    def loop_extension(loop)
      "!\xFF\x0BNETSCAPE2.0\x03\x01".b + [loop].pack("v") + "\0".b
    end

    def graphic_control(delay_ms, transparent_index)
      delay = [[(Integer(delay_ms) / 10.0).round, 0].max, 65_535].min
      packed = transparent_index ? 1 : 0
      "!\xF9\x04".b + [packed, delay, transparent_index || 0].pack("CvC") + "\0".b
    end

    def image_descriptor(rect, bits)
      x, y, width, height = rect
      [44, x, y, width, height, 0].pack("CvvvvC")
    end

    def sub_blocks(bytes, minimum_code_size)
      output = minimum_code_size.chr
      bytes.bytes.each_slice(255) { |slice| output << slice.length.chr << slice.pack("C*") }
      output << "\0".b
    end

    def lzw(indices, minimum_code_size)
      clear = 1 << minimum_code_size
      ending = clear + 1
      dictionary = {}
      next_code = ending + 1
      code_size = minimum_code_size + 1
      writer = BitWriter.new
      writer.write(clear, code_size)
      prefix = nil
      indices.bytes.each do |value|
        if prefix.nil?
          prefix = value
          next
        end
        key = [prefix, value]
        if dictionary.key?(key)
          prefix = dictionary[key]
          next
        end
        writer.write(prefix, code_size)
        if next_code < 4096
          dictionary[key] = next_code
          next_code += 1
          code_size += 1 if next_code > (1 << code_size) && code_size < 12
        else
          writer.write(clear, code_size)
          dictionary.clear
          next_code = ending + 1
          code_size = minimum_code_size + 1
        end
        prefix = value
      end
      writer.write(prefix, code_size) unless prefix.nil?
      writer.write(ending, code_size)
      writer.finish
    end

    class BitWriter
      def initialize
        @bytes = String.new(encoding: Encoding::BINARY)
        @buffer = 0
        @bits = 0
      end

      def write(value, width)
        @buffer |= value << @bits
        @bits += width
        while @bits >= 8
          @bytes << (@buffer & 255)
          @buffer >>= 8
          @bits -= 8
        end
      end

      def finish
        @bytes << (@buffer & 255) if @bits.positive?
        @bytes
      end
    end

    private_class_method :reserve_transparency, :loop_extension, :graphic_control, :image_descriptor,
      :sub_blocks, :lzw
  end
end
