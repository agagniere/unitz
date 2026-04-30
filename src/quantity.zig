const std = @import("std");
const unit_namespace = @import("unit.zig");
const eval_namespace = @import("eval.zig");

/// True iff `T` is a `Quantity` instantiation.
fn isQuantity(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"struct" => blk: {
            if (!@hasDecl(T, "unit") or !@hasDecl(T, "storage")) break :blk false;
            break :blk T == Quantity(T.unit, T.storage);
        },
        else => false,
    };
}

/// Return type of `Quantity.mul` / `Quantity.div`, with a clear `@compileError`
/// if `Other` is not a `Quantity`.
fn BinopReturnType(comptime A: type, comptime Other: type, comptime op: enum { mul, div }) type {
    if (!isQuantity(Other))
        @compileError(@tagName(op) ++ "() expects a Quantity, got '" ++ @typeName(Other) ++ "' (use scale() for a plain scalar)");
    return Quantity(switch (op) {
        .mul => A.unit.mul(Other.unit),
        .div => A.unit.div(Other.unit),
    }, A.storage);
}

/// A quantity is a measure expressed relatively to its unit.
///
/// Wraps a single `T` (typically `f32`/`f64`) tagged with a `Unit` type at
/// compile time. Arithmetic methods (`add`, `sub`, `mul`, `div`, `pow`,
/// `sqrt`) return a `Quantity` of the appropriate output unit, computed at
/// comptime; `to`/`from` convert between compatible units, while
/// dimension-mismatched conversions are caught as compile errors.
pub fn Quantity(comptime _unit: type, comptime T: type) type {
    return struct {
        value: T,

        pub const unit = _unit;
        pub const storage = T;

        const Self = @This();

        /// Construct a Quantity from a value already expressed in this unit.
        ///
        /// No conversion is performed — the value is stored verbatim. To
        /// build a Quantity from another Quantity in a different (but
        /// compatible) unit, use `from`.
        pub fn init(value: T) Self {
            return .{ .value = value };
        }

        /// Construct from another Quantity, converting to this unit.
        ///
        /// The source must be a `Quantity` whose storage matches `Self`; the
        /// units must be dimensionally compatible. Mismatches are caught as
        /// compile errors. For different storage types, use `floatCast`
        /// first.
        pub inline fn from(value: anytype) Self {
            const Other = @TypeOf(value);
            comptime if (!isQuantity(Other))
                @compileError("from() expects a Quantity, got '" ++ @typeName(Other) ++ "'");
            comptime if (Other.storage != Self.storage)
                @compileError("from() requires the source quantity to share the same storage type; convert it first with floatCast()");
            return value.to(Self);
        }

        /// Return the underlying numeric value.
        ///
        /// The value is in `Self`'s unit; no conversion is performed. To
        /// read the value in a different compatible unit, use `toVal`.
        pub fn val(self: Self) T {
            return self.value;
        }

        /// Return the negation of this quantity.
        ///
        /// Unit and storage are unchanged; only the sign of the value flips.
        pub fn negate(self: Self) Self {
            return Self.init(-self.value);
        }

        /// Add another quantity in the same unit.
        ///
        /// The two operands must have the same `Self` type — same unit *and*
        /// same storage. To add a quantity in a compatible-but-different
        /// unit, convert it first with `to`.
        pub fn add(self: Self, other: Self) Self {
            return Self.init(self.value + other.value);
        }

        /// Subtract another quantity in the same unit.
        ///
        /// Same constraints as `add`: identical `Self` type required.
        pub fn sub(self: Self, other: Self) Self {
            return Self.init(self.value - other.value);
        }

        /// Multiply by another quantity; the result's unit is the product.
        ///
        /// E.g. a speed times a duration yields a distance. The other
        /// operand must be a `Quantity`; for plain scalars use `scale`.
        pub fn mul(self: Self, other: anytype) BinopReturnType(Self, @TypeOf(other), .mul) {
            return .{ .value = self.value * other.value };
        }

        /// Divide by another quantity; the result's unit is the quotient.
        ///
        /// E.g. a distance divided by a duration yields a speed. The other
        /// operand must be a `Quantity`; for plain scalars use `scale` with
        /// the reciprocal.
        pub fn div(self: Self, other: anytype) BinopReturnType(Self, @TypeOf(other), .div) {
            return .{ .value = self.value / other.value };
        }

        /// Raise to an integer power; the unit's exponents are scaled
        /// accordingly.
        ///
        /// `power` must be a `comptime_int`. The numeric value is raised
        /// via `std.math.pow`.
        pub fn pow(self: Self, power: comptime_int) Quantity(Self.unit.pow(power), T) {
            return .{ .value = std.math.pow(T, self.value, power) };
        }

        /// Convert to a compatible Quantity type.
        ///
        /// `dest` must be a `Quantity` with the same storage type and a
        /// dimensionally compatible unit. Conversion multiplies by
        /// `unit_from.factor / unit_to.factor`. Mismatches are caught as
        /// compile errors.
        pub inline fn to(self: Self, dest: type) dest {
            comptime if (!isQuantity(dest))
                @compileError("to() expects a Quantity type, got '" ++ @typeName(dest) ++ "'");
            comptime if (Self.storage != dest.storage)
                @compileError("to() requires the destination quantity to share the same storage type; convert it first with floatCast()");
            const unit_from = Self.unit;
            const unit_to = dest.unit;
            comptime if (!unit_from.isCompatible(unit_to)) @compileError("Units are only interconvertible if they measure the same kind of dimension");
            const factor = unit_from.factor / unit_to.factor;
            return dest.init(self.value * factor);
        }

        /// Convert and return the value, shorthand for `to(dest).val()`.
        ///
        /// Useful in print sites where you want the number in a specific
        /// unit without binding an intermediate `Quantity`.
        pub inline fn toVal(self: Self, dest: type) T {
            return self.to(dest).val();
        }

        /// Cast the storage to a different float type, keeping the unit.
        ///
        /// Use to bridge between e.g. an `f32` quantity and an `f64` API,
        /// since `add`/`to`/`from` require matching storage types.
        pub inline fn floatCast(self: Self, dest: type) Quantity(Self.unit, dest) {
            return .{ .value = @floatCast(self.value) };
        }

        /// Square root; the unit's exponents are halved.
        ///
        /// The unit must have all-even dimension exponents (otherwise a
        /// compile error). The numeric value is taken via `@sqrt`.
        pub fn sqrt(self: Self) Quantity(Self.unit.sqrt(), Self.storage) {
            return .{ .value = @sqrt(self.value) };
        }

        /// Multiply the value by a scalar without changing the unit.
        ///
        /// `scalar` is in the same storage type as `Self`. For unit-changing
        /// products use `mul`.
        pub fn scale(self: Self, scalar: Self.storage) Self {
            return .{ .value = self.value * scalar };
        }
    };
}

/// Generate default quantities from default units, plus a comptime `eval`
/// helper bound to the given storage type.
fn Quantities(T: type) type {
    const decls = @typeInfo(unit_namespace.units).@"struct".decls;

    const Helpers = struct {
        /// Build a Quantity type from a unit expression, with the storage `T`
        /// captured from the surrounding `Quantities(T)`. Pass `.{}` for `inputs`
        /// when the expression contains no user-defined identifiers.
        fn eval(comptime expr: []const u8, inputs: anytype) type {
            return Quantity(eval_namespace.evalUnit(expr, inputs), T);
        }
    };

    // The `units` namespace also exposes non-type decls (e.g. its own `eval`).
    // Skip them — only Unit types map to Quantity fields.
    const N = blk: {
        var n: usize = 1; // +1 for our own `eval` helper
        for (decls) |decl| {
            if (@TypeOf(@field(unit_namespace.units, decl.name)) == type) n += 1;
        }
        break :blk n;
    };

    var field_names: [N][]const u8 = undefined;
    var field_types: [N]type = undefined;
    var field_attrs: [N]std.builtin.Type.StructField.Attributes = undefined;

    var i: usize = 0;
    for (decls) |decl| {
        if (@TypeOf(@field(unit_namespace.units, decl.name)) != type) continue;
        field_names[i] = decl.name;
        field_types[i] = type;
        field_attrs[i] = .{
            .@"comptime" = true,
            .@"align" = @alignOf(T),
            .default_value_ptr = &Quantity(@field(unit_namespace.units, decl.name), T),
        };
        i += 1;
    }

    field_names[i] = "eval";
    field_types[i] = @TypeOf(Helpers.eval);
    field_attrs[i] = .{
        .@"comptime" = true,
        .default_value_ptr = &Helpers.eval,
    };

    return @Struct(.auto, null, &field_names, &field_types, &field_attrs);
}

/// Comptime namespace bundling every unit from `units` as a `Quantity` type
/// bound to storage `T`. Each `pub const X = Unit(...)` in `units` becomes a
/// field `X` of type `Quantity(units.X, T)`:
///
/// ```zig
/// const u = quantities(f32);
/// const distance: u.meter = .init(1);
/// const work: u.joule = .init(0);
/// ```
///
/// The namespace also carries an `eval` helper, equivalent to
/// `Quantity(units.eval(expr, inputs), T)`. Pass `.{}` for `inputs` when the
/// expression has no user-defined identifiers:
///
/// ```zig
/// pub fn eval(comptime expr: []const u8, inputs: anytype) type
///
/// const kilowatthour = u.eval("kW * h", .{});
/// const @"kg/m3"     = u.eval("kg / m^3", .{});
/// ```
///
/// Because the returned struct is reified at comptime via `@Struct`, neither
/// the per-unit fields nor `eval` are discoverable through `zig build docs`;
/// they are documented here for that reason.
pub fn quantities(T: type) Quantities(T) {
    return .{};
}

test "quantities(T).eval shorthand" {
    const u = quantities(f32);

    // Common case: no custom identifiers
    const kilowatthour = u.eval("kW * h", .{});
    try comptime std.testing.expectEqual(eval_namespace.evalQuantity(f32, "kW * h", .{}), kilowatthour);

    const energy: kilowatthour = .init(2.5);
    try std.testing.expectEqual(2.5, energy.val());

    // Advanced case: pass user-defined identifiers
    const slug = eval_namespace.evalUnit("32.174_049 * lb", .{});
    const lbf = u.eval("ft * my_slug / s^2", .{ .my_slug = slug });
    try comptime std.testing.expectEqual(
        eval_namespace.evalQuantity(f32, "ft * my_slug / s^2", .{ .my_slug = slug }),
        lbf,
    );
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

    try std.testing.expectApproxEqAbs(3.2808, one_meter.toVal(ft), 0.000_1);
    try std.testing.expectApproxEqAbs(0.000_539_96, one_meter.toVal(nmi), 0.000_000_01);
    try std.testing.expectApproxEqAbs(6_076.115_49, one_naticalMile.toVal(ft), 0.000_001);

    // Convert temperatures
    const brine_freezing_point: R = .init(459.67);
    const water_freezing_point: K = .init(273.15);
    const water_boiling_point: K = .init(273.15 + 99.9839);

    try std.testing.expectApproxEqAbs(255.37, brine_freezing_point.toVal(K), 0.01);
    try std.testing.expectApproxEqAbs(491.67, water_freezing_point.toVal(R), 0.01);
    try std.testing.expectApproxEqAbs(671.6410, water_boiling_point.toVal(R), 0.0001);

    // Define new units and perform conversions
    // We recompute the pound-force from its definition
    // "The pound-force is the product of one avoirdupois pound and the standard acceleration due to gravity"
    const @"m/s2" = Quantity(m.unit.div(s.unit.pow(2)), f32);
    const @"ft/s2" = Quantity(ft.unit.div(s.unit.pow(2)), f32);

    const g = @"m/s2".init(9.806_65);
    try std.testing.expectApproxEqAbs(32.174_049, g.toVal(@"ft/s2"), 0.000_001);

    const lbf = Quantity(ft.unit.mul(lb.unit).div(s.unit.pow(2)).scale(32.174_049), f32);

    const one_lbf = lbf.init(1);

    try std.testing.expectApproxEqAbs(4.448_221_615, one_lbf.toVal(N), 0.000_001);

    // Recompute one imperial horsepower, from the definition
    // "One imperial horsepower lifts 550 pounds by 1 foot in 1 second"
    const @"ft.lbf/min" = Quantity(ft.unit.mul(lbf.unit).div(u.minute.unit), f32);

    const one_hp = lbf.init(550).mul(ft.init(1.0)).div(s.init(1.0));

    try std.testing.expectApproxEqAbs(33_000.0, one_hp.toVal(@"ft.lbf/min"), 0.001);
    try std.testing.expectApproxEqAbs(745.699_871_582, one_hp.toVal(W), 0.000_1);

    // Convert pressure
    const u_64 = quantities(f64);
    const atm32 = u.standard_atmosphere;
    const atm64 = u_64.standard_atmosphere;
    const @"lb/ft2 32" = Quantity(lbf.unit.div(ft.unit.pow(2)), f32);
    const @"lb/ft2 64" = Quantity(lbf.unit.div(ft.unit.pow(2)), f64);

    const one_atm_32: atm32 = .init(1);
    const one_atm_64: atm64 = one_atm_32.floatCast(f64);

    try std.testing.expectApproxEqAbs(2116, one_atm_64.toVal(@"lb/ft2 64"), 0.3);
    try std.testing.expectApproxEqAbs(2116, one_atm_64.floatCast(f32).toVal(@"lb/ft2 32"), 0.3);
}
