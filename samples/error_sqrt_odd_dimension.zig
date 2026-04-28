// Taking the square root of a unit whose dimension exponents are not all even.

const unitz = @import("unitz");
const u = unitz.quantities(f32);

pub fn main() void {
    const length: u.meter = .init(4);
    const root = length.sqrt();
    _ = root;
}

// Expected error:
//   src/unit.zig:100:17: error: Unit.sqrt requires every dimension exponent to be even
