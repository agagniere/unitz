// Calling .to() between units of different dimensions.

const unitz = @import("unitz");
const units = unitz.quantities(f32);

const J = units.joule;
const hp = units.imperial_horsepower;

pub fn main() void {
    const engine_power: hp = .init(130);
    const energy = engine_power.to(J);
    _ = energy;
}

// Expected error:
//   src/quantity.zig:84:60: error: Units are only interconvertible if they measure the same kind of dimension
