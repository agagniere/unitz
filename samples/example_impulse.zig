// Advanced example from the README: redefine slug and pound-force from
// their definitions, compute an impulse in lbf·s, then convert to N·s
// before passing it to a function that expects metric units.

const std = @import("std");
const unitz = @import("unitz");

const slug = unitz.evalUnit("32.174_049 * lb", .{});
const lbf = unitz.evalQuantity(f32, "ft * my_slug / s^2", .{ .my_slug = slug });
const @"lbf.s" = unitz.evalQuantity(f32, "my_lbf * s", .{ .my_lbf = lbf.unit });
const @"N.s" = unitz.evalQuantity(f32, "N * s", .{});
const @"μs" = unitz.evalQuantity(f32, "us", .{});

fn compute_impulse(force: lbf, delta: @"μs") @"lbf.s" {
    return .from(force.mul(delta)); // The .from converts to the target unit
}

fn compute_trajectory(impulse: @"N.s") void {
    std.debug.print("Impulse: {} N·s\n", .{impulse.val()});
}

pub fn main() void {
    const force = lbf.init(123.0);
    const delta = @"μs".init(45.0);

    compute_trajectory(.from(compute_impulse(force, delta)));
}
