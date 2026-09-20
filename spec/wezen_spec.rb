# frozen_string_literal: true

RSpec.describe Wezen do
  let(:red) { [255, 0, 0, 255].pack("C4") }
  let(:blue) { [0, 0, 255, 255].pack("C4") }

  it "stores and coalesces deterministic frames" do
    animation = Wezen::Animation.new(width: 1, height: 1)
    animation.add(red, delay_ms: 50).add(red, delay_ms: 50)
    expect(animation.size).to eq(1)
    expect(animation.duration_ms).to eq(100)
  end

  it "writes deterministic APNG and GIF bytes" do
    animation = Wezen::Animation.new(width: 1, height: 1)
    animation.add(red, delay_ms: 100).add(blue, delay_ms: 100)
    expect(Wezen::APNG.encode(animation)).to eq(Wezen::APNG.encode(animation))
    expect(Wezen::GIF.encode(animation, dither: :none)).to eq(Wezen::GIF.encode(animation, dither: :none))
    expect(Wezen::APNG.encode(animation)).to start_with(Wezen::PNG::SIGNATURE)
    expect(Wezen::GIF.encode(animation, dither: :none)).to start_with("GIF89a")
  end

  it "round-trips opaque APNG and GIF frames" do
    animation = Wezen::Animation.new(width: 2, height: 1)
      .add(red + blue, delay_ms: 100)
      .add(blue + red, delay_ms: 100)

    apng_width, apng_height, apng_frames = APNGDecoder.decode(Wezen::APNG.encode(animation))
    expect([apng_width, apng_height, apng_frames]).to eq([2, 1, [red + blue, blue + red]])

    gif_width, gif_height, gif_frames = GIFDecoder.decode(Wezen::GIF.encode(animation, colors: 2, dither: :none))
    expect([gif_width, gif_height, gif_frames]).to eq([2, 1, [red + blue, blue + red]])
  end

  it "keeps GIF code sizes aligned for larger runs" do
    animation = Wezen::Animation.new(width: 4, height: 3).add(red * 12, delay_ms: 100)

    gif_width, gif_height, gif_frames = GIFDecoder.decode(Wezen::GIF.encode(animation, colors: 2, dither: :none))
    expect([gif_width, gif_height, gif_frames]).to eq([4, 3, [red * 12]])
  end

  it "finds changed image bounds" do
    expect(Wezen::Image.diff_bounds(red + red, red + blue, 2, 1)).to eq([1, 0, 1, 1])
    expect(Wezen::Image.diff_bounds(red, red, 1, 1)).to be_nil
  end

  it "writes asciinema v2 events" do
    event = Wezen::Cast::Event.new(0.5, :output, "hello")
    expect(Wezen::Cast.encode(width: 80, height: 24, events: [event])).to include('[0.5,"o","hello"]')
  end
end
