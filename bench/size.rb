# frozen_string_literal: true

require "wezen"

width = 80
height = 45
animation = Wezen::Animation.new(width: width, height: height)
12.times do |frame|
  pixels = String.new(capacity: width * height * 4, encoding: Encoding::BINARY)
  height.times do |y|
    width.times do |x|
      active = (x - frame * 3).abs < 24 && (y - 90).abs < 24
      pixels << [active ? 240 : 24, active ? 180 : 32, active ? 60 : 48, 255].pack("C4")
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
