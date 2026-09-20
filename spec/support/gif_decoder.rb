# frozen_string_literal: true

module GIFDecoder
  module_function

  def decode(bytes)
    raise ArgumentError, "not a GIF" unless bytes.start_with?("GIF87a", "GIF89a")

    width, height, packed, _background, _aspect = bytes.byteslice(6, 7).unpack("vvC3")
    offset = 13
    global_palette = read_palette(bytes, offset, packed)
    offset += global_palette ? 3 * (1 << ((packed & 7) + 1)) : 0
    canvas = "\0".b * (width * height * 4)
    frames = []
    gce = {delay: 0, transparent: nil, disposal: 0}
    previous = nil

    while offset < bytes.bytesize
      case bytes.getbyte(offset)
      when 0x21
        label = bytes.getbyte(offset + 1)
        if label == 0xF9
          raise ArgumentError, "invalid graphic control extension" unless bytes.getbyte(offset + 2) == 4
          flags, delay, transparent = bytes.byteslice(offset + 3, 4).unpack("CvvC")
          gce = {delay: delay * 10, transparent: (flags & 1).positive? ? transparent : nil, disposal: (flags >> 2) & 7}
          offset += 8
        else
          offset += 2
          _data, offset = sub_blocks(bytes, offset)
        end
      when 0x2C
        x, y, frame_width, frame_height, descriptor = bytes.byteslice(offset + 1, 9).unpack("vvvvC")
        offset += 10
        local_palette = read_palette(bytes, offset, descriptor)
        palette = local_palette || global_palette
        offset += local_palette ? 3 * (1 << ((descriptor & 7) + 1)) : 0
        minimum = bytes.getbyte(offset)
        compressed, offset = sub_blocks(bytes, offset + 1)
        indices = lzw_decode(compressed, minimum, frame_width * frame_height)
        previous = canvas.dup if gce[:disposal] == 3
        frame_height.times do |row|
          frame_width.times do |column|
            index = indices[row * frame_width + column]
            next if index == gce[:transparent]

            color = palette.fetch(index)
            canvas[((y + row) * width + x + column) * 4, 4] = [*color, 255].pack("C4")
          end
        end
        frames << canvas.dup
        case gce[:disposal]
        when 2
          frame_height.times { |row| canvas[((y + row) * width + x) * 4, frame_width * 4] = "\0".b * (frame_width * 4) }
        when 3 then canvas = previous
        end
        gce = {delay: 0, transparent: nil, disposal: 0}
      when 0x3B
        break
      else
        raise ArgumentError, "invalid GIF block"
      end
    end
    [width, height, frames]
  end

  def read_palette(bytes, offset, packed)
    return unless (packed & 0x80).positive?

    count = 1 << ((packed & 7) + 1)
    bytes.byteslice(offset, count * 3).bytes.each_slice(3).to_a
  end

  def sub_blocks(bytes, offset)
    output = +"".b
    loop do
      length = bytes.getbyte(offset)
      offset += 1
      break [output, offset] if length.zero?

      output << bytes.byteslice(offset, length)
      offset += length
    end
  end

  def lzw_decode(bytes, minimum_code_size, expected)
    clear = 1 << minimum_code_size
    ending = clear + 1
    dictionary = (0...clear).map { |index| [index] } + [nil, nil]
    code_size = minimum_code_size + 1
    next_code = ending + 1
    bit_offset = 0
    previous = nil
    output = []
    read = lambda do |width|
      value = 0
      width.times { |bit| value |= ((bytes.getbyte((bit_offset + bit) / 8) >> ((bit_offset + bit) % 8)) & 1) << bit }
      bit_offset += width
      value
    end
    loop do
      code = read.call(code_size)
      if code == clear
        dictionary = (0...clear).map { |index| [index] } + [nil, nil]
        code_size = minimum_code_size + 1
        next_code = ending + 1
        previous = nil
        next
      end
      break if code == ending

      entry = if code < dictionary.length && dictionary[code]
        dictionary[code]
      elsif code == next_code && previous
        previous + [previous.first]
      else
        raise ArgumentError, "invalid GIF LZW code"
      end
      output.concat(entry)
      break if output.length >= expected
      if previous
        dictionary << previous + [entry.first] if dictionary.length < 4096
        next_code += 1
        code_size += 1 if next_code == (1 << code_size) && code_size < 12
      end
      previous = entry
    end
    raise ArgumentError, "invalid GIF pixel count" unless output.length == expected

    output
  end
end
