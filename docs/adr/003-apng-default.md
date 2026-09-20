# ADR 003: APNG is the default

- Status: Accepted
- Date: 2026-09-20

## Context

Recorded UI frames commonly use transparency and more than 256 colors. GIF is
widely supported but requires palette quantization and has limited alpha
semantics. APNG preserves the source pixel format while remaining a portable
single-file animation.

The credible alternatives were GIF as the only output, a sequence of PNG
files, or APNG as the lossless default with GIF for compatibility.

## Decision

APNG is the default animation output and preserves RGBA pixels. GIF remains an
explicit compatibility output with deterministic palette quantization.

## Consequences

The default path keeps colors and transparency intact, while callers targeting
GIF-only viewers can opt in to the documented quantization behavior. APNG
support is not universal in every legacy viewer; revisit the default only if
the supported playback targets change.
