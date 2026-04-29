# Samples

Two kinds of samples live here:

* `example_*.zig` — runnable programs adapted from the README.
* `error_*.zig`   — short programs that demonstrate a specific
  compile-time error from `unitz`. The expected error message is written
  at the bottom of every sample.

Run an example or trigger an error with:

```sh
zig build example_aircraft_speed
zig build error_to_incompatible_units
```

Plain `zig build` builds and installs every example into `zig-out/bin/`.
The `error_*` samples are opt-in (they're each expected to fail to
compile). `zig build --list-steps` lists every sample as a step.

## Examples

| File | Adapted from |
|---|---|
| [example_aircraft_speed.zig](example_aircraft_speed.zig)     | README "Showcase" |
| [example_body_mass_index.zig](example_body_mass_index.zig)   | README "Simple example" |
| [example_impulse.zig](example_impulse.zig)                   | README "Advanced example" |

## Errors

| File | Demonstrates |
|---|---|
| [error_to_incompatible_units.zig](error_to_incompatible_units.zig)     | `.to()` between units of different dimensions |
| [error_to_invalid_destination.zig](error_to_invalid_destination.zig)   | `.to()` called with a non-`Quantity` type |
| [error_to_storage_mismatch.zig](error_to_storage_mismatch.zig)         | `.to()` between `Quantity` types whose storage differs |
| [error_from_invalid_source.zig](error_from_invalid_source.zig)         | `.from()` called with a raw value instead of a `Quantity` |
| [error_from_storage_mismatch.zig](error_from_storage_mismatch.zig)     | `.from()` between `Quantity` types whose storage differs |
| [error_from_incompatible_units.zig](error_from_incompatible_units.zig) | `.from()` between units of different dimensions |
| [error_mul_invalid_argument.zig](error_mul_invalid_argument.zig)       | `.mul()` with a raw scalar (use `.scale()` instead) |
| [error_div_invalid_argument.zig](error_div_invalid_argument.zig)       | `.div()` with a raw scalar (use `.scale()` instead) |
| [error_sqrt_odd_dimension.zig](error_sqrt_odd_dimension.zig)           | `.sqrt()` of a unit whose dimension exponents are not all even |
