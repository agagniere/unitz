// Passing a raw value (not a Quantity) to .from().

const u = @import("unitz").quantities(f32);

pub fn main() void {
    const m: u.meter = .from(1.0);
    _ = m;
}

// Expected error:
//   src/quantity.zig:44:17: error: from() expects a Quantity, got 'comptime_float'
//   error_from_invalid_source.zig:6:29: note: called inline here
//       const m: u.meter = .from(1.0);
