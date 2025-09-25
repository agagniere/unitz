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

/// Generate default quantities from default units
fn Quantities(T: type) type {
    const units = @typeInfo(unit_namespace.units).@"struct".decls;
    var fields: [units.len]std.builtin.Type.StructField = undefined;
    for (&fields, units) |*quantity, unit| {
        quantity.name = unit.name;
        quantity.type = type;
        quantity.is_comptime = true;
        quantity.alignment = @alignOf(T);
        quantity.default_value_ptr = &Quantity(@field(unit_namespace.units, unit.name), T);
    }
    const result: std.builtin.Type = .{ .@"struct" = .{
        .layout = .auto,
        .fields = &fields,
        .decls = &.{},
        .is_tuple = false,
    } };
    return @Type(result);
}

/// To see the list of quantities, refer to the list of units in the `units` namespace
pub fn quantities(T: type) Quantities(T) {
    return .{};
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
    const R = u.rankine;
    const K = u.kelvin;

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

    // Convert temperatures
    const brine_freezing_point: R = .init(459.67);
    const water_freezing_point: K = .init(273.15);
    const water_boiling_point: K = .init(273.15 + 99.9839);

    try std.testing.expectApproxEqAbs(255.37, brine_freezing_point.to_val(K), 0.01);
    try std.testing.expectApproxEqAbs(491.67, water_freezing_point.to_val(R), 0.01);
    try std.testing.expectApproxEqAbs(671.6410, water_boiling_point.to_val(R), 0.0001);

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
