# frozen_string_literal: true

require "wezen"

width = 1_000
height = 700
animation = Wezen::Animation.new(width: width, height: height)
background = [24, 32, 48, 255].pack("C4") * (width * height)
120.times do |frame|
  pixels = background.dup
  cursor_x = (frame * 7) % (width - 40)
  cursor_y = height / 2
  24.times do |y|
    40.times do |x|
      offset = ((cursor_y + y) * width + cursor_x + x) * 4
      pixels.setbyte(offset, 240)
      pixels.setbyte(offset + 1, 180)
      pixels.setbyte(offset + 2, 60)
    end
  end
  animation.add(pixels, delay_ms: 83)
end

apng = Wezen::APNG.encode(animation)
gif = Wezen::GIF.encode(animation, colors: 32, dither: :bayer)
puts "APNG #{apng.bytesize} bytes"
puts "GIF  #{gif.bytesize} bytes"
if ENV["BUDGET"] == "1"
  raise "APNG size budget exceeded" if apng.bytesize > 1_572_864
  raise "GIF size budget exceeded" if gif.bytesize > 2_097_152
end
