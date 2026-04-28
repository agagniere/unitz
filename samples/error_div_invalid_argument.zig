// Dividing a Quantity by a raw scalar instead of another Quantity.

const unitz = @import("unitz");
const u = unitz.quantities(f32);

pub fn main() void {
    const distance: u.meter = .init(10);
    const x = distance.div(2);
    _ = x;
}

// Expected error:
//   src/quantity.zig:19:9: error: div() expects a Quantity, got 'comptime_int' (use scale() for a plain scalar)
