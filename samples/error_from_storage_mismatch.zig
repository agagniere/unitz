// Calling .from() with a Quantity of a different storage type.

const unitz = @import("unitz");
const q32 = unitz.quantities(f32);
const q64 = unitz.quantities(f64);

pub fn main() void {
    const a: q32.meter = .init(1);
    const b: q64.meter = .from(a);
    _ = b;
}

// Expected error:
//   src/quantity.zig:45:17: error: from() requires the source quantity to share the same storage type; convert it first with floatCast()
