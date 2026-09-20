<h1 align="center">Wezen</h1>

<p align="center">
  <strong>Dependency-free Ruby encoders for deterministic APNG, GIF, PNG, and asciinema demo media.</strong>
</p>

<p align="center">
  <a href="https://rubygems.org/gems/wezen"><img src="https://img.shields.io/gem/v/wezen.svg?color=b7a66f" alt="Gem version"></a>
  <a href="https://github.com/noxdea/wezen/actions/workflows/main.yml"><img src="https://github.com/noxdea/wezen/actions/workflows/main.yml/badge.svg" alt="CI status"></a>
  <img src="https://img.shields.io/badge/Ruby-3.1%2B-cc342d" alt="Ruby 3.1 or newer">
  <a href="LICENSE.txt"><img src="https://img.shields.io/badge/license-MIT-4c8eda" alt="MIT license"></a>
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#installation">Installation</a> ·
  <a href="#quick-start">Quick start</a> ·
  <a href="#output-formats">Output formats</a> ·
  <a href="#development">Development</a>
</p>

---

Wezen turns RGBA frames and terminal events into portable, reproducible demo
assets. It is built for documentation, fixtures, and recording pipelines where
the same input should produce the same bytes.

The name comes from δ Canis Majoris: its IAU name derives from the Arabic
*al-wazn*, meaning “the weight.”

## Features

- Lossless APNG with optional changed-frame rectangles, plus PNG stills
- GIF89a encoding with deterministic median-cut palettes and dithering
- Frame coalescing, scaling, cropping, sampling, blending, and change bounds
- Asciinema v2 JSON Lines output for terminal recordings
- Byte-stable output for identical inputs
- No runtime dependencies beyond Ruby's `zlib` and `json` standard libraries

## Installation

Add Wezen to your Gemfile:

```ruby
gem "wezen"
```

Then install dependencies:

```sh
bundle install
```

Or install the gem directly:

```sh
gem install wezen
```

Wezen requires Ruby 3.1 or newer.

## Quick start

Create a two-frame animation and write lossless APNG and compatible GIF
versions:

```ruby
require "wezen"

animation = Wezen::Animation.new(width: 2, height: 1)
animation.add([255, 0, 0, 255, 0, 0, 255, 255].pack("C*"), delay_ms: 100)
animation.add([255, 0, 0, 255, 0, 255, 0, 255].pack("C*"), delay_ms: 100)

Wezen::APNG.write("demo.apng", animation)
Wezen::GIF.write("demo.gif", animation, dither: :bayer)
```

Frames are packed RGBA strings in row-major order. `Animation#add` merges
identical consecutive frames and adds their delays automatically.

## Output formats

| Format | Use case | Behavior |
|---|---|---|
| APNG | Lossless animation | Preserves RGBA pixels and stores changed rectangles when possible |
| GIF89a | Broad compatibility | Uses a deterministic global palette with optional dithering |
| PNG | Still frames | Writes a single lossless RGBA image |
| Asciinema v2 | Terminal sessions | Writes chronological output, input, and resize events as JSON Lines |

### APNG

APNG is the preferred animation format when color and alpha fidelity matter:

```ruby
bytes = Wezen::APNG.encode(animation, compression: 9, diff: true)
File.binwrite("demo.apng", bytes)
```

### GIF

Control palette size, palette strategy, dithering, and frame differences:

```ruby
Wezen::GIF.write(
  "demo.gif",
  animation,
  colors: 128,
  palette: :global,
  dither: :floyd_steinberg,
  diff: true
)
```

Provide a `Wezen::Palette` when the recording needs a fixed application palette.
Supported dithering modes are `:floyd_steinberg`, `:bayer`, and `:none`.

### PNG

Write a single packed RGBA frame:

```ruby
frame = animation.each.first
Wezen::PNG.write("frame.png", animation.width, animation.height, frame.rgba)
```

### Asciinema casts

Create an asciinema v2 recording from chronological terminal events:

```ruby
events = [
  Wezen::Cast::Event.new(0.0, :output, "$ bundle exec rake\r\n"),
  Wezen::Cast::Event.new(0.4, :output, "12 examples, 0 failures\r\n")
]

Wezen::Cast.write(
  "demo.cast",
  width: 80,
  height: 24,
  title: "Test run",
  events: events
)
```

Event kinds are `:output`, `:input`, and `:resize`.

## Transform animations

Every transformation returns a new `Wezen::Animation`:

```ruby
animation = animation.coalesce(tolerance: 2)
animation = animation.scale(to_width: 640, to_height: 360)
animation = animation.crop([0, 0, 320, 180])
animation = animation.drop_to(fps: 12)
```

Use `Wezen::Image` directly for lower-level scaling, cropping, alpha blending,
and changed-pixel bounds.

## Design decisions

Wezen deliberately ships encoders without runtime decoders. This keeps the gem
small, portable, and focused while round-trip tests validate generated media.

The architecture records explain the durable format choices:

- [Encode-only scope](docs/adr/001-encode-only.md)
- [Deterministic global palette](docs/adr/002-global-palette.md)
- [APNG as the default animation format](docs/adr/003-apng-default.md)

## Development

```sh
bundle install
bundle exec rake
bundle exec rake bench
bundle exec rbs -I sig validate
gem build --strict wezen.gemspec
```

## Contributing

Bug reports and pull requests are welcome in the
[GitHub repository](https://github.com/noxdea/wezen).

## License

Wezen is available under the [MIT License](LICENSE.txt).
