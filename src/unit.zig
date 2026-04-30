const std = @import("std");
const prefix_namespace = @import("prefix.zig");
const eval_namespace = @import("eval.zig");

const Prefix = prefix_namespace.Prefix;
const prefixFactor = prefix_namespace.prefixFactor;

/// Raise x to the power n
fn comptimePow(comptime x: comptime_float, comptime n: comptime_int) comptime_float {
    if (n < 0) unreachable;
    return switch (n) {
        0 => 1.0,
        1 => x,
        else => x * comptimePow(x, n - 1),
    };
}

/// A unit is a quantity in a dimension, used to measure things in the same dimension.
///
/// Returns an anonymous struct *type* parameterized by the five SI base
/// dimension exponents (meter, second, kilogram, ampere, kelvin) and a
/// scalar `Factor` relative to the SI base. Two `Unit(...)` types are
/// interconvertible iff their five exponents match; the factor differs and
/// gives the conversion ratio.
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
                comptimePow(Self.factor, n),
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

        /// Apply a metric prefix (e.g. `.kilo`, `.milli`) to this unit.
        ///
        /// Equivalent to `scale(prefixFactor(_prefix))`. The result is a unit
        /// compatible with `Self` (same dimensions, scaled factor).
        pub fn prefix(_prefix: Prefix) type {
            return Self.scale(prefixFactor(_prefix));
        }

        /// Two units are compatible if they measure the same kind of dimension.
        ///
        /// Compares only the five dimension exponents, ignoring the factor.
        /// Compatible units can be converted into one another via
        /// `Quantity.to`/`from`.
        pub fn isCompatible(other: type) bool {
            return Self.meter == other.meter and Self.second == other.second and Self.kilogram == other.kilogram and Self.ampere == other.ampere and Self.kelvin == other.kelvin;
        }

        /// Define a new unit that is the square root of this one.
        ///
        /// Each dimension exponent is divided by two; passing a unit whose
        /// exponents are not all even raises a comptime error. The factor is
        /// taken at comptime via `@sqrt`.
        pub fn sqrt() type {
            comptime if (@mod(Self.meter, 2) != 0 or
                @mod(Self.second, 2) != 0 or
                @mod(Self.kilogram, 2) != 0 or
                @mod(Self.ampere, 2) != 0 or
                @mod(Self.kelvin, 2) != 0)
                @compileError("Unit.sqrt requires every dimension exponent to be even");
            return Unit(
                @divExact(Self.meter, 2),
                @divExact(Self.second, 2),
                @divExact(Self.kilogram, 2),
                @divExact(Self.ampere, 2),
                @divExact(Self.kelvin, 2),
                @sqrt(Self.factor),
            );
        }
    };
}

/// Abstract units used to tag Quantities.
///
/// Each `pub const X = Unit(...)` here is a Unit *type*, the building block
/// for `Quantity(X, T)`. The catalog covers SI base/derived units plus
/// common imperial and CGS units (see source for the full list). Use
/// `units.eval` to compose new units from a string expression.
pub const units = struct {
    pub const one = Unit(0, 0, 0, 0, 0, 1.0);

    // Distance
    /// m
    pub const meter = Unit(1, 0, 0, 0, 0, 1.0);
    /// inch
    pub const inch = meter.scale(0.0254);
    /// ft
    pub const foot = inch.scale(12);
    /// yd
    pub const yard = foot.scale(3);
    /// mi
    pub const mile = yard.scale(1_760);
    /// nmi
    pub const nautical_mile = meter.scale(1_852);
    /// fur
    pub const furlong = yard.scale(220);

    // Angle
    /// rad
    pub const radian = meter.div(meter);
    pub const semicircle = radian.scale(std.math.pi);
    /// rev
    pub const revolution = semicircle.scale(2);
    /// deg
    pub const arcdegree = semicircle.scale(1.0 / 180.0);

    // Duration
    /// s
    pub const second = Unit(0, 1, 0, 0, 0, 1.0);
    /// min
    pub const minute = second.scale(60);
    /// h
    pub const hour = minute.scale(60);
    /// d
    pub const day = hour.scale(24);
    /// wk
    pub const week = day.scale(7);

    // Mass
    /// kg
    pub const kilogram = Unit(0, 0, 1, 0, 0, 1.0);
    /// g
    pub const gram = kilogram.scale(1e-3);
    /// t (Metric ton)
    pub const tonne = kilogram.scale(1e3);
    pub const dram = gram.scale(1.771_845_195_312_5);
    /// oz
    pub const ounce = dram.scale(16.0);
    /// lb
    pub const pound = ounce.scale(16.0);
    /// slug
    pub const slug = pound.scale(32.174_05);

    // Electric current
    /// A
    pub const ampere = Unit(0, 0, 0, 1, 0, 1.0);

    // Temperature
    /// K
    pub const kelvin = Unit(0, 0, 0, 0, 1, 1.0);
    /// R
    pub const rankine = kelvin.scale(5.0 / 9.0);

    // Frequency
    /// Hz
    pub const hertz = one.div(second);

    // Force
    /// N
    pub const newton = kilogram.mul(meter).div(second.pow(2));
    /// lbf
    pub const pound_force = slug.mul(foot).div(second.pow(2));

    // Pressure
    /// Pa
    pub const pascal = newton.div(meter.pow(2));
    /// bar
    pub const bar = pascal.prefix(.kilo).scale(100);
    /// at
    pub const technical_atmosphere = pascal.scale(98_066.5);
    /// atm
    pub const standard_atmosphere = pascal.scale(101325);
    /// Torr
    pub const torr = standard_atmosphere.scale(1.0 / 760.0);

    // Energy
    /// J
    pub const joule = newton.mul(meter);
    /// cal
    pub const calorie = joule.scale(4.184);

    // Power
    /// W
    pub const watt = joule.div(second);
    /// hp
    pub const imperial_horsepower = watt.scale(745.699_871_582_270_22);

    // Magnetic flux density
    /// T
    pub const tesla = weber.div(meter.pow(2));
    /// G
    pub const gauss = tesla.scale(1e-4);

    // Volume
    /// l
    pub const liter = meter.prefix(.deci).pow(3);

    // Speed
    /// kn
    pub const knot = nautical_mile.div(hour);

    // Viscosity (dynamic/absolute)
    /// Pl
    pub const poiseuille = pascal.mul(second);
    /// P
    pub const poise = poiseuille.prefix(.deci);

    /// C
    pub const coulomb = second.mul(ampere);
    /// V
    pub const volt = joule.div(coulomb);
    /// F
    pub const farad = coulomb.div(volt);
    /// Ohm
    pub const ohm = volt.div(ampere);
    /// S
    pub const siemens = ampere.div(volt);
    /// Wb
    pub const weber = joule.div(ampere);
    /// H
    pub const henry = weber.div(second);

    /// Build a Unit type from an expression like `"kg / m^3"`. Pass `.{}`
    /// for `inputs` when the expression contains no user-defined identifiers.
    pub fn eval(comptime expr: []const u8, inputs: anytype) type {
        return eval_namespace.evalUnit(expr, inputs);
    }
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

    try comptime std.testing.expectEqual(u.joule.div(u.kilogram).sqrt(), u.meter.div(u.second));
}

test "units.eval shorthand" {
    try comptime std.testing.expectEqual(units.meter.div(units.second), units.eval("m / s", .{}));
    try comptime std.testing.expectEqual(units.joule.prefix(.mega).scale(3.6), units.eval("kW * h", .{}));
}
