# ADR 001: Encode-only scope

- Status: Accepted
- Date: 2026-09-20

## Context

Wezen is a small, dependency-free library for turning frames and terminal
events into portable media. Adding decoders would increase the runtime surface
and introduce format-specific behavior that callers do not need to produce
media.

The credible alternatives were to ship decoders with the gem, depend on an
external image library, or keep decoding support in tests only.

## Decision

Wezen writes deterministic APNG, GIF, PNG, and asciinema streams. Decoders
remain test support and are not part of the runtime gem.

## Consequences

The runtime remains small, portable, and dependency-free, while round-trip
tests still validate the encoders. Callers that need to inspect or decode
media must provide that capability separately; revisit this decision only if
encoding users also require a stable decoding API.
