// Passing a non-Quantity type as the destination of .to().

const unitz = @import("unitz");
const u = unitz.quantities(f32);

pub fn main() void {
    const distance: u.meter = .init(1);
    const x = distance.to(f32);
    _ = x;
}

// Expected error:
//   src/quantity.zig:79:17: error: to() expects a Quantity type, got 'f32'
