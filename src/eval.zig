const std = @import("std");
const comath = @import("comath");
const unitz = @import("root.zig");

const p = unitz.Prefix;

const relations = .{
    .@"+" = comath.relation(.left, 1),
    .@"-" = comath.relation(.left, 1),

    .@"*" = comath.relation(.left, 2),
    .@"/" = comath.relation(.left, 2),

    .@"^" = comath.relation(.left, 3),
};
const BinaryOperators = std.meta.FieldEnum(@TypeOf(relations));

const prefixes = .{
    .T = p.tera,
    .G = p.giga,
    .M = p.mega,
    .k = p.kilo,
    .h = p.hecto,
    .d = p.deci,
    .c = p.centi,
    .m = p.milli,
    .u = p.micro,
    .n = p.nano,
    .p = p.pico,
};
const PrefixSymbols = std.meta.FieldEnum(@TypeOf(prefixes));

pub inline fn unitzContext(identifiers: anytype) UnitzContext(@TypeOf(identifiers)) {
    return .{ .identifiers = identifiers };
}

pub fn UnitzContext(comptime _builtin_identifiers: type) type {
    return struct {
        const Self = @This();
        const U = unitz.units;
        const builtin_identifiers = _builtin_identifiers;

        identifiers: Self.builtin_identifiers,

        /// Should return `true` for any string of symbols corresponding to a recognized binary operator.
        pub inline fn matchBinOp(comptime str: []const u8) bool {
            return @hasField(BinaryOperators, str);
        }

        /// Returns the order of the binary operators `lhs` and `rhs`, where `matchBinOp(lhs) = true`, and
        /// `matchBinOp(rhs) = true`.
        pub inline fn orderBinOp(comptime lhs: []const u8, comptime rhs: []const u8) ?comath.Order {
            if (!@hasField(BinaryOperators, lhs)) return null;
            if (!@hasField(BinaryOperators, rhs)) return null;
            return @field(relations, lhs).order(@field(relations, rhs));
        }

        /// Determines the value and type of number literals.
        pub fn EvalNumberLiteral(comptime src: []const u8) type {
            return switch (std.zig.parseNumberLiteral(src)) {
                .int => comptime_int,
                .float => comptime_float,
                else => noreturn,
            };
        }
        pub fn evalNumberLiteral(comptime src: []const u8) EvalNumberLiteral(src) {
            return switch (std.zig.parseNumberLiteral(src)) {
                .int => |val| val,
                .big_int => @compileError("Big Ints are not supported for now"),
                .float => std.fmt.parseFloat(f128, src) catch |err| @compileError(@errorName(err)),
                .failure => |failure| @compileError(switch (failure) {
                    .leading_zero => "Invalid leading zeroes in '" ++ src ++ "'",
                    .digit_after_base => "Expected digit after base in '" ++ src ++ "'",
                    .upper_case_base, .invalid_float_base => "Invalid base in '" ++ src ++ "'",
                    .repeated_underscore, .invalid_underscore_after_special => "Invalid underscore in '" ++ src ++ "'",
                    .invalid_digit => |info| std.fmt.comptimePrint(
                        "Invalid digit '{c}' in '{s}' with base '{s}'",
                        .{ src[info.i], src, @tagName(info.base) },
                    ),
                    .invalid_digit_exponent => |exp_idx| std.fmt.comptimePrint(
                        "Invalid exponent '{c}' in '{s}'",
                        .{ src[exp_idx], src },
                    ),
                    .duplicate_period => "Duplicate periods in '" ++ src ++ "'",
                    .duplicate_exponent => "Duplicate exponents in '" ++ src ++ "'",
                    .exponent_after_underscore => "Exponent after underscore in '" ++ src ++ "'",
                    .special_after_underscore => |spec_idx| std.fmt.comptimePrint(
                        "Invalid '{c}' after underscore in '{s}'",
                        .{ src[spec_idx], src },
                    ),
                    .trailing_special,
                    .trailing_underscore,
                    .invalid_character,
                    .invalid_exponent_sign,
                    => |err_idx| std.fmt.comptimePrint(
                        "Invalid '{c}' in '{s}'",
                        .{ src[err_idx], src },
                    ),
                }),
            };
        }

        /// Determines the value and type of identifiers, overriding those which would otherwise be
        /// determined via the `inputs` struct. `EvalIdent` returning `noreturn` causes
        /// `eval` to instead look for the identifier in the `inputs` struct.
        pub fn EvalIdent(comptime ident: []const u8) type {
            if (@hasField(Self.builtin_identifiers, ident))
                return type;
            if (@hasField(Self.builtin_identifiers, ident[1..]) and @hasField(PrefixSymbols, ident[0..1]))
                return type;
            return noreturn;
        }

        pub fn evalIdent(ctx: Self, comptime ident: []const u8) !EvalIdent(ident) {
            if (@hasField(Self.builtin_identifiers, ident))
                return @field(ctx.identifiers, ident);
            if (@hasField(Self.builtin_identifiers, ident[1..]) and @hasField(PrefixSymbols, ident[0..1]))
                return @field(ctx.identifiers, ident[1..]).prefix(@field(prefixes, ident[0..1]));
            comptime unreachable;
        }

        /// Corresponds to `lhs op rhs`
        /// In most contexts, it should be sufficient to assume `@hasField(BinOp, op)`.
        pub fn EvalBinOp(comptime Lhs: type, comptime op: []const u8, comptime Rhs: type) type {
            _ = Lhs;
            _ = op;
            _ = Rhs;
            return type;
        }
        pub fn evalBinOp(ctx: @This(), lhs: anytype, comptime op: []const u8, rhs: anytype) !EvalBinOp(@TypeOf(lhs), op, @TypeOf(rhs)) {
            _ = ctx;

            const L = switch (@TypeOf(lhs)) {
                comptime_int, comptime_float => U.one.scale(lhs),
                else => lhs,
            };

            return switch (@field(BinaryOperators, op)) {
                .@"+" => L.add(rhs),
                .@"-" => L.sub(rhs),
                .@"*" => L.mul(rhs),
                .@"/" => L.div(rhs),
                .@"^" => L.pow(rhs),
            };
        }
    };
}

pub inline fn evalUnit(comptime expr: []const u8, inputs: anytype) type {
    const u = unitz.units;
    const ctx = unitzContext(.{
        .m = u.meter,
        .s = u.second,
        .kg = u.kilogram,
        .A = u.ampere,
        .K = u.kelvin,

        .g = u.gram,
        .t = u.tonne,
        .l = u.liter,

        .Hz = u.hertz,
        .N = u.newton,
        .Pa = u.pascal,
        .J = u.joule,
        .W = u.watt,
        .C = u.coulomb,
        .V = u.volt,
        .F = u.farad,
        .Ohm = u.ohm,
        .S = u.siemens,
        .Wb = u.weber,
        .T = u.tesla,
        .H = u.henry,

        .min = u.minute,
        .h = u.hour,
        .d = u.day,
        .wk = u.week,

        .rad = u.radian,
        .deg = u.arcdegree,

        .G = u.gauss,
        .cal = u.calorie,
        .ft = u.foot,
        .fur = u.furlong,
        .hp = u.imperial_horsepower,
        .inch = u.inch,
        .kn = u.knot,
        .lb = u.pound,
        .mi = u.mile,
        .nmi = u.nautical_mile,
        .oz = u.ounce,
        .yd = u.yard,
    });
    return comath.eval(expr, ctx, inputs) catch unreachable;
}

pub inline fn evalQuantity(comptime T: type, comptime expr: []const u8, inputs: anytype) type {
    return unitz.Quantity(evalUnit(expr, inputs), T);
}

test UnitzContext {
    const u = unitz.units;

    const J_per_s = evalUnit("J / s", .{});
    comptime try std.testing.expectEqual(u.watt, J_per_s);

    const kg_per_m3 = evalUnit("kg / m^3", .{});
    comptime try std.testing.expectEqual(u.kilogram.div(u.meter.pow(3)), kg_per_m3);

    const per_s = evalUnit("1 / s", .{});
    comptime try std.testing.expectEqual(u.hertz, per_s);

    const milligram = evalUnit("mg", .{});
    comptime try std.testing.expectEqual(u.gram.prefix(.milli), milligram);

    const kilojoule = evalUnit("kJ", .{});
    comptime try std.testing.expectEqual(u.joule.prefix(.kilo), kilojoule);

    const kilowatthour = evalUnit("kW * h", .{});
    comptime try std.testing.expectEqual(u.joule.prefix(.mega).scale(3.6), kilowatthour);
}

test evalQuantity {
    const slug = evalUnit("32.174_049 * lb", .{});
    const lbf = evalQuantity(f32, "ft * slug / s^2", .{ .slug = slug });
    const centinewton = evalQuantity(f32, "cN", .{});

    const one_lbf: lbf = .init(1);
    try std.testing.expectApproxEqAbs(444.822_161_5, one_lbf.to_val(centinewton), 0.000_000_1);
}
