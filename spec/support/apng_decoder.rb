# frozen_string_literal: true

require "zlib"

module APNGDecoder
  module_function

  def decode(bytes)
    raise ArgumentError, "not a PNG" unless bytes.start_with?("\x89PNG\r\n\x1A\n".b)

    width = height = nil
    pending = nil
    frames = []
    offset = 8
    while offset + 12 <= bytes.bytesize
      size = bytes.byteslice(offset, 4).unpack1("N")
      kind = bytes.byteslice(offset + 4, 4)
      data = bytes.byteslice(offset + 8, size)
      offset += size + 12
      case kind
      when "IHDR"
        width, height, depth, type = data.unpack("NNC2")
        raise ArgumentError, "unsupported APNG pixel format" unless depth == 8 && type == 6
      when "fcTL"
        frames << pending if pending
        _sequence, frame_width, frame_height, x, y, _num, _den, dispose, blend = data.unpack("N5n2C2")
        pending = {width: frame_width, height: frame_height, x: x, y: y, dispose: dispose, blend: blend, data: +"".b}
      when "IDAT"
        pending ||= {width: width, height: height, x: 0, y: 0, dispose: 0, blend: 0, data: +"".b}
        pending[:data] << data
      when "fdAT"
        raise ArgumentError, "fdAT without fcTL" unless pending

        pending[:data] << data.byteslice(4..)
      when "IEND"
        frames << pending if pending
        break
      end
    end
    raise ArgumentError, "invalid APNG" unless width && height && !frames.empty?

    canvas = "\0".b * (width * height * 4)
    decoded = frames.map do |frame|
      before = canvas.dup
      pixels = inflate(frame[:data], frame[:width], frame[:height])
      frame[:height].times do |row|
        frame[:width].times do |column|
          source = pixels.byteslice((row * frame[:width] + column) * 4, 4)
          index = ((frame[:y] + row) * width + frame[:x] + column) * 4
          canvas[index, 4] = frame[:blend].zero? ? source : source_over(canvas.byteslice(index, 4), source)
        end
      end
      output = canvas.dup
      case frame[:dispose]
      when 1
        frame[:height].times { |row| canvas[((frame[:y] + row) * width + frame[:x]) * 4, frame[:width] * 4] = "\0".b * (frame[:width] * 4) }
      when 2 then canvas = before
      end
      output
    end
    [width, height, decoded]
  end

  def inflate(data, width, height)
    raw = Zlib::Inflate.inflate(data)
    stride = width * 4
    raise ArgumentError, "invalid APNG scanlines" unless raw.bytesize == (stride + 1) * height

    output = +"".b
    height.times do |row|
      filter = raw.getbyte(row * (stride + 1))
      raise ArgumentError, "unsupported APNG filter" unless filter.zero?

      output << raw.byteslice(row * (stride + 1) + 1, stride)
    end
    output
  end

  def source_over(destination, source)
    sr, sg, sb, sa = source.bytes
    dr, dg, db, da = destination.bytes
    alpha = sa / 255.0
    [
      (sr * alpha + dr * (1 - alpha)).round,
      (sg * alpha + dg * (1 - alpha)).round,
      (sb * alpha + db * (1 - alpha)).round,
      (sa + da * (1 - alpha)).round
    ].pack("C4")
  end
end
