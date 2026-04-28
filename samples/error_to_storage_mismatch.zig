// Calling .to() between Quantity types with different storage.

const unitz = @import("unitz");
const q32 = unitz.quantities(f32);
const q64 = unitz.quantities(f64);

pub fn main() void {
    const a: q32.meter = .init(1);
    const b = a.to(q64.meter);
    _ = b;
}

// Expected error:
//   src/quantity.zig:81:17: error: to() requires the destination quantity to share the same storage type; convert it first with floatCast()
