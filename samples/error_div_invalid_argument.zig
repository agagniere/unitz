// Dividing a Quantity by a raw scalar instead of another Quantity.

const u = @import("unitz").quantities(f32);

pub fn main() void {
    const distance: u.meter = .init(10);
    const x = distance.div(2);
    _ = x;
}

// Expected error:
//   src/quantity.zig:20:9: error: div() expects a Quantity, got 'comptime_int' (use scale() for a plain scalar)
