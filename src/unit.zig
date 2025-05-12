const std = @import("std");
const prefix_namespace = @import("prefix.zig");

const Prefix = prefix_namespace.Prefix;
const prefixFactor = prefix_namespace.prefixFactor;

/// Raise x to the power n
fn comptime_pow(comptime x: comptime_float, comptime n: comptime_int) comptime_float {
    if (n < 0) unreachable;
    return switch (n) {
        0 => 1.0,
        1 => x,
        else => x * comptime_pow(x, n - 1),
    };
}

/// A unit is a quantity in a dimension, used to measure things in the same dimension.
pub fn Unit(
    comptime Meter: comptime_int,
    comptime Second: comptime_int,
    comptime Kilogram: comptime_int,
    comptime Ampere: comptime_int,
    comptime Kelvin: comptime_int,
    comptime Factor: comptime_float,
) type {
    return struct {
        pub const meter = Meter;
        pub const second = Second;
        pub const kilogram = Kilogram;
        pub const ampere = Ampere;
        pub const kelvin = Kelvin;
        pub const factor = Factor;

        const Self = @This();

        /// Define a new unit that is the product of two units
        pub fn mul(other: type) type {
            return Unit(
                Self.meter + other.meter,
                Self.second + other.second,
                Self.kilogram + other.kilogram,
                Self.ampere + other.ampere,
                Self.kelvin + other.kelvin,
                Self.factor * other.factor,
            );
        }

        /// Define a new unit that is this unit divided by another
        pub fn div(other: type) type {
            return Unit(
                Self.meter - other.meter,
                Self.second - other.second,
                Self.kilogram - other.kilogram,
                Self.ampere - other.ampere,
                Self.kelvin - other.kelvin,
                Self.factor / other.factor,
            );
        }

        /// Define a new unit that is this unit raised to the power of n
        pub fn pow(n: comptime_int) type {
            return Unit(
                Self.meter * n,
                Self.second * n,
                Self.kilogram * n,
                Self.ampere * n,
                Self.kelvin * n,
                comptime_pow(Self.factor, n),
            );
        }

        /// Define a new unit that is proportional to this unit.
        /// It will be compatible with this unit
        pub fn scale(scalar: comptime_float) type {
            return Unit(
                Self.meter,
                Self.second,
                Self.kilogram,
                Self.ampere,
                Self.kelvin,
                Self.factor * scalar,
            );
        }

        pub fn prefix(_prefix: Prefix) type {
            return Self.scale(prefixFactor(_prefix));
        }

        /// Two units are compatible if they measure the same kind of dimension
        pub fn is_compatible(other: type) bool {
            return Self.meter == other.meter and Self.second == other.second and Self.kilogram == other.kilogram and Self.ampere == other.ampere and Self.kelvin == other.kelvin;
        }
    };
}

/// Abstract units used to tag Quantities
pub const units = struct {
    pub const one = Unit(0, 0, 0, 0, 0, 1.0);
    pub const radian = one;
    pub const turn = radian.scale(2 * std.math.pi);
    pub const arcdegree = turn.scale(1.0 / 360.0);

    pub const meter = Unit(1, 0, 0, 0, 0, 1.0);
    pub const second = Unit(0, 1, 0, 0, 0, 1.0);
    pub const kilogram = Unit(0, 0, 1, 0, 0, 1.0);
    pub const ampere = Unit(0, 0, 0, 1, 0, 1.0);
    pub const kelvin = Unit(0, 0, 0, 0, 1, 1.0);

    pub const gram = kilogram.scale(1e-3);
    /// Metric ton
    pub const tonne = kilogram.scale(1e3);
    pub const liter = meter.prefix(.deci).pow(3);

    pub const minute = second.scale(60);
    pub const hour = minute.scale(60);
    pub const day = hour.scale(24);
    pub const week = day.scale(7);

    pub const hertz = one.div(second);
    pub const newton = kilogram.mul(meter).div(second.pow(2));
    pub const pascal = newton.div(meter.pow(2));
    pub const joule = newton.mul(meter);
    pub const watt = joule.div(second);
    pub const coulomb = second.mul(ampere);
    pub const volt = joule.div(coulomb);
    pub const farad = coulomb.div(volt);
    pub const ohm = volt.div(ampere);
    pub const siemens = ampere.div(volt);
    pub const weber = joule.div(ampere);
    pub const tesla = weber.div(meter.pow(2));
    pub const henry = weber.div(second);

    pub const inch = meter.scale(0.0254);
    pub const foot = inch.scale(12);
    pub const yard = foot.scale(3);
    pub const mile = yard.scale(1_760);
    pub const nautical_mile = meter.scale(1_852);
    pub const furlong = yard.scale(220);

    pub const dram = gram.scale(1.771_845_195_312_5);
    pub const ounce = dram.scale(16.0);
    pub const pound = ounce.scale(16.0);

    pub const knot = nautical_mile.div(hour);
    pub const imperial_horsepower = watt.scale(745.699_871_582_270_22);
    pub const gauss = tesla.scale(1e-4);
    pub const calorie = joule.scale(4.184);
};

test Unit {
    const u = units;
    try comptime std.testing.expectEqual(u.newton.mul(u.meter), u.meter.mul(u.newton));

    try comptime std.testing.expectEqual(Unit(0, -1, 0, 0, 0, 1.0), u.hertz);
    try comptime std.testing.expectEqual(Unit(1, -2, 1, 0, 0, 1.0), u.newton);
    try comptime std.testing.expectEqual(Unit(-1, -2, 1, 0, 0, 1.0), u.pascal);
    try comptime std.testing.expectEqual(Unit(2, -2, 1, 0, 0, 1.0), u.joule);
    try comptime std.testing.expectEqual(Unit(2, -3, 1, 0, 0, 1.0), u.watt);
    try comptime std.testing.expectEqual(Unit(0, 1, 0, 1, 0, 1.0), u.coulomb);
    try comptime std.testing.expectEqual(Unit(2, -3, 1, -1, 0, 1.0), u.volt);

    try comptime std.testing.expectEqual(u.meter.scale(0.3048), u.foot);
    try comptime std.testing.expectEqual(u.meter.scale(0.9144), u.yard);

    try comptime std.testing.expectEqual(u.meter.scale(1000), u.meter.prefix(.kilo));
}
