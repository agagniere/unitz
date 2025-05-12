const std = @import("std");
const unit_namespace = @import("unit.zig");

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

        pub fn negate(self: Self) Self {
            return Self.init(-self.value);
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

        pub fn pow(self: Self, power: comptime_int) Quantity(Self.unit.pow(power), T) {
            return .{ .value = std.math.pow(T, self.value, power) };
        }

        pub inline fn to(self: Self, dest: type) dest {
            const unit_from = Self.unit;
            const unit_to = dest.unit;
            comptime if (!unit_from.is_compatible(unit_to)) @compileError("Units are only interconvertible if they measure the same kind of dimension");
            const factor = unit_from.factor / unit_to.factor;
            return dest.init(self.value * factor);
        }

        pub inline fn to_val(self: Self, dest: type) T {
            return self.to(dest).val();
        }
    };
}

pub fn quantities(T: type) type {
    const u = unit_namespace.units;
    return struct {
        pub const unitless = Quantity(u.one, T);
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
        pub const liter = Quantity(u.liter, T);

        pub const minute = Quantity(u.minute, T);
        pub const hour = Quantity(u.hour, T);
        pub const day = Quantity(u.day, T);
        pub const week = Quantity(u.week, T);

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
        pub const furlong = Quantity(u.furlong, T);

        pub const dram = Quantity(u.dram, T);
        pub const ounce = Quantity(u.ounce, T);
        pub const pound = Quantity(u.pound, T);

        pub const knot = Quantity(u.knot, T);
        pub const imperial_horsepower = Quantity(u.imperial_horsepower, T);
        pub const gauss = Quantity(u.gauss, T);
        pub const calorie = Quantity(u.calorie, T);
    };
}

test Quantity {
    const u = quantities(f32);
    const m = u.meter;
    const s = u.second;
    const @"m/s" = Quantity(u.meter.unit.div(u.second.unit), f32);
    const m2 = Quantity(u.meter.unit.pow(2), f32);
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
