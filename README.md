# Wezen

Wezen is named for δ Canis Majoris, whose IAU name comes from the Arabic
*al-wazn* (“the weight”). It is a dependency-free Ruby encoder for deterministic
demo media.

## Features

- Lossless APNG and PNG output with optional frame rectangles
- GIF89a output with deterministic median-cut palettes and dithering
- Pixel scaling, cropping, alpha blending, and change bounds
- Asciinema v2 JSON Lines casts
- No runtime dependencies beyond Ruby's `zlib` and `json` standard libraries

## Installation

```sh
gem install wezen
```

## Quick start

```ruby
require "wezen"

animation = Wezen::Animation.new(width: 2, height: 1)
animation.add([255, 0, 0, 255, 0, 0, 255, 255].pack("C*"), delay_ms: 100)
animation.add([255, 0, 0, 255, 0, 255, 0, 255].pack("C*"), delay_ms: 100)

Wezen::APNG.write("demo.apng", animation)
Wezen::GIF.write("demo.gif", animation, dither: :bayer)
```

`Animation` accepts RGBA strings in row-major order. Repeated frames are
coalesced and their delays are added. Encoding the same animation twice yields
the same bytes.

## Development

```sh
bundle install
bundle exec rake
bundle exec rbs -I sig validate
gem build --strict wezen.gemspec
```

The runtime gem intentionally contains encoders only; decoder helpers belong in
tests so the package stays small and dependency-free.

## License

MIT. See [LICENSE.txt](LICENSE.txt).
