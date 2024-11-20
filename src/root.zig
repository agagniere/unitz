const std = @import("std");

/// A metric prefix precedes a basic unit of measure to indicate a multiple or submultiple of the unit
pub const Prefix = enum {
    tera,
    giga,
    mega,
    kilo,
    hecto,
    deca,
    one,
    deci,
    centi,
    milli,
    micro,
    nano,
    pico,
};

/// Expressed in term of the base unit
fn prefixFactor(comptime prefix: Prefix) comptime_float {
    return switch (prefix) {
        .tera => 1e12,
        .giga => 1e9,
        .mega => 1e6,
        .kilo => 1e3,
        .hecto => 100,
        .deca => 10,
        .one => 1,
        .deci => 0.1,
        .centi => 0.01,
        .milli => 1e-3,
        .micro => 1e-6,
        .nano => 1e-9,
        .pico => 1e-12,
    };
}

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

        /// Define a new unit that is proportional to this unit
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

    pub const minute = second.scale(60);
    pub const hour = minute.scale(60);
    pub const day = hour.scale(24);

    pub const square_meter = meter.pow(2);
    pub const cubic_meter = meter.pow(3);
    pub const kilogram_per_cubic_meter = kilogram.div(cubic_meter);

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

    pub const dram = gram.scale(1.771_845_195_312_5);
    pub const ounce = dram.scale(16.0);
    pub const pound = ounce.scale(16.0);

    pub const meter_per_second = meter.div(second);
    pub const kilometer_per_hour = meter.prefix(.kilo).div(hour);
    pub const knot = nautical_mile.div(hour);

    pub const imperial_horsepower = watt.scale(745.699_871_582_270_22);
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
}

/// A quantity is a measure expressed relatively to its unit
pub fn Quantity(comptime _unit: type, comptime T: type) type {
    return struct {
        value: T,

        pub const unit = _unit;

        const Self = @This();

        pub fn init(value: T) Self {
            return .{ .value = value };
        }

        pub fn val(self: Self) T {
            return self.value;
        }

        pub fn add(self: Self, other: Self) Self {
            return Self.init(self.value + other.value);
        }

        pub fn sub(self: Self, other: Self) Self {
            return Self.init(self.value - other.value);
        }

        pub fn mul(self: Self, other: anytype) Quantity(Self.unit.mul(@TypeOf(other).unit), T) {
            return .{ .value = self.value * other.value };
        }

        pub fn div(self: Self, other: anytype) Quantity(Self.unit.div(@TypeOf(other).unit), T) {
            return .{ .value = self.value / other.value };
        }

        pub fn to(self: Self, dest: type) dest {
            const unit_from = Self.unit;
            const unit_to = dest.unit;
            comptime if (!unit_from.is_compatible(unit_to)) @compileError("Units are only interconvertible if they measure the same kind of dimension");
            const factor = unit_from.factor / unit_to.factor;
            return dest.init(self.value * factor);
        }

        pub fn to_val(self: Self, dest: type) T {
            return self.to(dest).val();
        }
    };
}

///
pub fn quantities(T: type) type {
    const u = units;
    return struct {
        pub const radian = Quantity(u.radian, T);
        pub const turn = Quantity(u.turn, T);
        pub const arcdegree = Quantity(u.arcdegree, T);

        pub const meter = Quantity(u.meter, T);
        pub const second = Quantity(u.second, T);
        pub const kilogram = Quantity(u.kilogram, T);
        pub const ampere = Quantity(u.ampere, T);
        pub const kelvin = Quantity(u.kelvin, T);

        pub const gram = Quantity(u.gram, T);
        /// Metric ton
        pub const tonne = Quantity(u.tonne, T);

        pub const minute = Quantity(u.minute, T);
        pub const hour = Quantity(u.hour, T);
        pub const day = Quantity(u.day, T);

        pub const square_meter = Quantity(u.square_meter, T);
        pub const cubic_meter = Quantity(u.cubic_meter, T);
        pub const kilogram_per_cubic_meter = Quantity(u.kilogram_per_cubic_meter, T);

        pub const hertz = Quantity(u.hertz, T);
        pub const newton = Quantity(u.newton, T);
        pub const pascal = Quantity(u.pascal, T);
        pub const joule = Quantity(u.joule, T);
        pub const watt = Quantity(u.watt, T);
        pub const coulomb = Quantity(u.coulomb, T);
        pub const volt = Quantity(u.volt, T);
        pub const farad = Quantity(u.farad, T);
        pub const ohm = Quantity(u.ohm, T);
        pub const siemens = Quantity(u.siemens, T);
        pub const weber = Quantity(u.weber, T);
        pub const tesla = Quantity(u.tesla, T);
        pub const henry = Quantity(u.henry, T);

        pub const inch = Quantity(u.inch, T);
        pub const foot = Quantity(u.foot, T);
        pub const yard = Quantity(u.yard, T);
        pub const mile = Quantity(u.mile, T);
        pub const nautical_mile = Quantity(u.nautical_mile, T);

        pub const dram = Quantity(u.dram, T);
        pub const ounce = Quantity(u.ounce, T);
        pub const pound = Quantity(u.pound, T);

        pub const meter_per_second = Quantity(u.meter_per_second, T);
        pub const kilometer_per_hour = Quantity(u.kilometer_per_hour, T);
        pub const knot = Quantity(u.knot, T);

        pub const imperial_horsepower = Quantity(u.imperial_horsepower, T);
    };
}

test Quantity {
    const u = quantities(f32);
    const m = u.meter;
    const s = u.second;
    const @"m/s" = u.meter_per_second;
    const m2 = u.square_meter;
    const lb = u.pound;
    const N = u.newton;
    const W = u.watt;

    // Compute a speed from a distance and a duration
    const D = m.init(23);
    const T = s.init(17);
    const V = D.div(T);

    try comptime std.testing.expectEqual(@"m/s", @TypeOf(V));
    try comptime std.testing.expectEqual(m.unit.div(s.unit), @TypeOf(V).unit);
    try std.testing.expectEqual(23.0 / 17.0, V.val());

    // Compute a surface
    const S = D.mul(D);

    try comptime std.testing.expectEqual(m2, @TypeOf(S));
    try std.testing.expectEqual(23.0 * 23.0, S.val());

    // Convert lengths
    const ft = u.foot;
    const nmi = u.nautical_mile;
    const one_meter = m.init(1.0);
    const one_naticalMile = nmi.init(1.0);

    try std.testing.expectApproxEqAbs(3.2808, one_meter.to_val(ft), 0.000_1);
    try std.testing.expectApproxEqAbs(0.000_539_96, one_meter.to_val(nmi), 0.000_000_01);
    try std.testing.expectApproxEqAbs(6_076.115_49, one_naticalMile.to_val(ft), 0.000_001);

    // Define new units and perform conversions
    // We recompute the pound-force from its definition
    // "The pound-force is the product of one avoirdupois pound and the standard acceleration due to gravity"
    const @"m/s2" = Quantity(m.unit.div(s.unit.pow(2)), f32);
    const @"ft/s2" = Quantity(ft.unit.div(s.unit.pow(2)), f32);

    const g = @"m/s2".init(9.806_65);
    try std.testing.expectApproxEqAbs(32.174_049, g.to_val(@"ft/s2"), 0.000_001);

    const lbf = Quantity(ft.unit.mul(lb.unit).div(s.unit.pow(2)).scale(32.174_049), f32);

    const one_lbf = lbf.init(1);

    try std.testing.expectApproxEqAbs(4.448_221_615, one_lbf.to_val(N), 0.000_001);

    // Recompute one imperial horsepower, from the definition
    // "One imperial horsepower lifts 550 pounds by 1 foot in 1 second"
    const @"ft.lbf/min" = Quantity(ft.unit.mul(lbf.unit).div(u.minute.unit), f32);

    const one_hp = lbf.init(550).mul(ft.init(1.0)).div(s.init(1.0));

    try std.testing.expectApproxEqAbs(33_000.0, one_hp.to_val(@"ft.lbf/min"), 0.001);
    try std.testing.expectApproxEqAbs(745.699_871_582, one_hp.to_val(W), 0.000_1);
}
