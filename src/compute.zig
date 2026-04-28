const std = @import("std");
const comath = @import("comath");
const unitz = @import("root.zig");

const relations = .{
    .@"+" = comath.relation(.left, 1),
    .@"-" = comath.relation(.left, 1),
    .@"*" = comath.relation(.left, 2),
    .@"/" = comath.relation(.left, 2),
};

/// Context for evaluating an expression on `Quantity` *values*.
/// Identifiers are looked up in the user-provided `inputs` struct; binary
/// operators dispatch to the corresponding `Quantity` method, so the resulting
/// unit follows naturally (a speed times a duration yields a distance).
pub const ComputeContext = struct {
    const Op = std.meta.FieldEnum(@TypeOf(relations));
    const UnOp = enum { @"-" };

    pub inline fn matchUnOp(comptime str: []const u8) bool {
        return @hasField(UnOp, str);
    }

    pub inline fn matchBinOp(comptime str: []const u8) bool {
        return @hasField(Op, str);
    }

    pub inline fn orderBinOp(comptime lhs: []const u8, comptime rhs: []const u8) ?comath.Order {
        if (!@hasField(Op, lhs)) return null;
        if (!@hasField(Op, rhs)) return null;
        return @field(relations, lhs).order(@field(relations, rhs));
    }

    /// Number literals are dimensionless quantities with `comptime_float` storage,
    /// so they can transparently coerce to whichever concrete float type they are
    /// combined with at the binary-op level.
    pub fn EvalNumberLiteral(comptime src: []const u8) type {
        _ = src;
        return unitz.Quantity(unitz.units.one, comptime_float);
    }

    pub fn evalNumberLiteral(comptime src: []const u8) EvalNumberLiteral(src) {
        return .{ .value = comath.ctx.defaultEvalNumberLiteral(src) };
    }

    pub const EvalIdent = {};
    pub const evalIdent = {};

    pub fn EvalUnOp(comptime op: []const u8, comptime T: type) type {
        _ = op;
        return T;
    }

    pub fn evalUnOp(_: ComputeContext, comptime op: []const u8, val: anytype) !EvalUnOp(op, @TypeOf(val)) {
        return switch (@field(UnOp, op)) {
            .@"-" => val.negate(),
        };
    }

    /// When one side has `comptime_float` storage (a literal) and the other has a
    /// concrete float storage, coerce the literal side to the concrete storage so
    /// that `Quantity`'s methods (which assume `Self.storage` for the result) work.
    fn Promoted(comptime A: type, comptime B: type) type {
        if (A.storage == comptime_float and B.storage != comptime_float)
            return unitz.Quantity(A.unit, B.storage);
        return A;
    }

    inline fn promoted(val: anytype, comptime Other: type) Promoted(@TypeOf(val), Other) {
        const Self = @TypeOf(val);
        if (Self.storage == comptime_float and Other.storage != comptime_float)
            return .{ .value = val.value };
        return val;
    }

    pub fn EvalBinOp(comptime Lhs: type, comptime op: []const u8, comptime Rhs: type) type {
        const lhs_undef: Promoted(Lhs, Rhs) = undefined;
        const rhs_undef: Promoted(Rhs, Lhs) = undefined;
        return switch (@field(Op, op)) {
            .@"+", .@"-" => blk: {
                if (Lhs.unit != Rhs.unit)
                    @compileError("Quantities can only be added or subtracted if they have the same unit");
                break :blk Promoted(Lhs, Rhs);
            },
            .@"*" => @TypeOf(lhs_undef.mul(rhs_undef)),
            .@"/" => @TypeOf(lhs_undef.div(rhs_undef)),
        };
    }

    pub fn evalBinOp(_: ComputeContext, lhs: anytype, comptime op: []const u8, rhs: anytype) !EvalBinOp(@TypeOf(lhs), op, @TypeOf(rhs)) {
        const L = promoted(lhs, @TypeOf(rhs));
        const R = promoted(rhs, @TypeOf(lhs));
        return switch (@field(Op, op)) {
            .@"+" => L.add(R),
            .@"-" => L.sub(R),
            .@"*" => L.mul(R),
            .@"/" => L.div(R),
        };
    }
};

/// Evaluate an arithmetic expression on `Quantity` values.
/// Each identifier in `expr` must correspond to a `Quantity` field in `inputs`.
/// Supports `+ - * /`. The result unit follows from the operations applied.
pub inline fn compute(comptime expr: []const u8, inputs: anytype) comath.Eval(expr, ComputeContext, @TypeOf(inputs)) {
    @setEvalBranchQuota(10_000);
    const ctx: ComputeContext = .{};
    return comath.eval(expr, ctx, inputs) catch unreachable;
}

test compute {
    const u = unitz.quantities(f32);
    const m = u.meter;
    const s = u.second;
    const @"m/s" = unitz.evalQuantity(f32, "m / s", .{});

    // a speed times a duration is a distance
    const speed: @"m/s" = .init(10);
    const duration: s = .init(5);
    const distance = compute("speed * duration", .{ .speed = speed, .duration = duration });

    try comptime std.testing.expectEqual(m, @TypeOf(distance));
    try std.testing.expectEqual(50, distance.val());

    // mixed arithmetic with operator precedence
    const a: m = .init(100);
    const b: @"m/s" = .init(10);
    const c: s = .init(5);
    const result = compute("a + b * c", .{ .a = a, .b = b, .c = c });

    try comptime std.testing.expectEqual(m, @TypeOf(result));
    try std.testing.expectEqual(150, result.val());

    // subtraction and division
    const energy = u.joule;
    const power = u.watt;
    const work: energy = .init(600);
    const elapsed: s = .init(3);
    const avg_power = compute("work / elapsed", .{ .work = work, .elapsed = elapsed });
    try comptime std.testing.expectEqual(power, @TypeOf(avg_power));
    try std.testing.expectEqual(200, avg_power.val());

    const remaining = compute("work - avg_power * elapsed", .{ .work = work, .avg_power = avg_power, .elapsed = elapsed });
    try comptime std.testing.expectEqual(energy, @TypeOf(remaining));
    try std.testing.expectEqual(0, remaining.val());

    // unary minus
    const back = compute("-distance", .{ .distance = distance });
    try comptime std.testing.expectEqual(m, @TypeOf(back));
    try std.testing.expectEqual(-50, back.val());

    const net = compute("a + -b * c", .{ .a = a, .b = b, .c = c });
    try comptime std.testing.expectEqual(m, @TypeOf(net));
    try std.testing.expectEqual(50, net.val());

    // numeric literals: dimensionless Quantity with comptime_float storage
    const dimensionless = unitz.Quantity(unitz.units.one, comptime_float);
    const five = compute("2 + 3", .{});
    try comptime std.testing.expectEqual(dimensionless, @TypeOf(five));
    try std.testing.expectEqual(5, five.val());

    // literal on either side of mul / div promotes to the quantity's storage
    const doubled = compute("2 * a", .{ .a = a });
    try comptime std.testing.expectEqual(m, @TypeOf(doubled));
    try std.testing.expectEqual(200, doubled.val());

    const half = compute("a / 2", .{ .a = a });
    try comptime std.testing.expectEqual(m, @TypeOf(half));
    try std.testing.expectEqual(50, half.val());

    // literal in a larger mixed expression
    const midpoint = compute("(a + b * c) / 2", .{ .a = a, .b = b, .c = c });
    try comptime std.testing.expectEqual(m, @TypeOf(midpoint));
    try std.testing.expectEqual(75, midpoint.val());
}
