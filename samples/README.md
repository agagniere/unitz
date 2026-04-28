# Sample errors

Each `error_*.zig` file in this directory is a short program that, when
compiled, produces a specific compile-time error from `unitz`. The
expected error message is written at the bottom of every sample.

To reproduce one, run from this directory:

```sh
zig build error_to_incompatible_units
```

`zig build --list-steps` lists every sample as a step. Plain `zig build`
without a step does nothing — none of the samples are part of the
default build (they are all expected to fail to compile).

| File | Demonstrates |
|---|---|
| [error_to_incompatible_units.zig](error_to_incompatible_units.zig)     | `.to()` between units of different dimensions |
| [error_to_invalid_destination.zig](error_to_invalid_destination.zig)   | `.to()` called with a non-`Quantity` type |
| [error_to_storage_mismatch.zig](error_to_storage_mismatch.zig)         | `.to()` between `Quantity` types whose storage differs |
| [error_from_invalid_source.zig](error_from_invalid_source.zig)         | `.from()` called with a raw value instead of a `Quantity` |
| [error_from_storage_mismatch.zig](error_from_storage_mismatch.zig)     | `.from()` between `Quantity` types whose storage differs |
| [error_mul_invalid_argument.zig](error_mul_invalid_argument.zig)       | `.mul()` with a raw scalar (use `.scale()` instead) |
| [error_div_invalid_argument.zig](error_div_invalid_argument.zig)       | `.div()` with a raw scalar (use `.scale()` instead) |
| [error_sqrt_odd_dimension.zig](error_sqrt_odd_dimension.zig)           | `.sqrt()` of a unit whose dimension exponents are not all even |
