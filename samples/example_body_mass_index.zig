// Simple example from the README: take a height and a weight in any
// length and mass units, return the BMI in kg/m².

const std = @import("std");
const unitz = @import("unitz");
const q = unitz.quantities(f32);

const m = q.meter;
const kg = q.kilogram;
const lb = q.pound;
const cm = unitz.evalQuantity(f32, "cm", .{});
const @"kg/m²" = unitz.evalQuantity(f32, "kg / m^2", .{});

fn body_mass_index(height: m, weight: kg) @"kg/m²" {
    return weight.div(height.pow(2));
}

pub fn main() void {
    const height: cm = .init(162);
    const weight: lb = .init(124);
    const bmi = body_mass_index(height.to(m), weight.to(kg));
    std.debug.print("BMI: {}\n", .{bmi.val()});
}
