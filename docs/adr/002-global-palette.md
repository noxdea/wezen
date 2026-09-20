# ADR 002: Deterministic global palette

- Status: Accepted
- Date: 2026-09-20

## Context

GIF has a single global color table in the common output path, while recorded
animations may contain more colors than that table can hold. Per-frame
palettes could preserve local colors better, but make frame differences and
output size less predictable.

The credible alternatives were a per-frame palette, a fixed application
palette, or one deterministic palette for the complete animation.

## Decision

GIF uses one median-cut palette for the animation. Palette axes, color ordering,
and tie-breaking are stable so identical inputs produce byte-identical output.

## Consequences

Palette construction is reproducible and shared across frames, which keeps
GIF output simple and suitable for size budgets. A global palette can represent
some local gradients less accurately than a per-frame palette; revisit this if
measured media quality requires adaptive palettes without compromising
determinism.
