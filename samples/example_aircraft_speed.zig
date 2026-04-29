// Showcase example from the README: pass a distance and a duration,
// return the speed converted to knots, and print every form along the way.

const std = @import("std");
const unitz = @import("unitz");
const units = unitz.quantities(f32);

const m = units.meter;
const s = units.second;
const kt = units.knot;
const @"km/h" = unitz.evalQuantity(f32, "km / h", .{});

fn aircraft_speed(distance: m, duration: s) kt {
    const speed = distance.div(duration); // value is in m/s
    const result: kt = .from(speed); // convert to target unit
    std.debug.print("Speed: {} m/s = {} kt = {} km/h\n", .{
        speed.val(),
        result.val(),
        speed.toVal(@"km/h"),
    });
    return result;
}

pub fn main() void {
    const distance: m = .init(1000);
    const duration: s = .init(60);
    _ = aircraft_speed(distance, duration);
}
