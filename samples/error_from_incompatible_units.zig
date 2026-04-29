// Calling .from() with a Quantity whose unit has a different dimension.

const units = @import("unitz").quantities(f32);

const J = units.joule;
const hp = units.imperial_horsepower;

pub fn main() void {
    const engine_power: hp = .init(130);
    const energy: J = .from(engine_power);
    _ = energy;
}

// Expected error:
//   src/quantity.zig:85:60: error: Units are only interconvertible if they measure the same kind of dimension
//   src/quantity.zig:47:28: note: called inline here
//       return value.to(Self);
//   error_from_incompatible_units.zig:10:28: note: called inline here
//       const energy: J = .from(engine_power);
