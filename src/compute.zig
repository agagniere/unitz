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

    pub const EvalNumberLiteral = comath.ctx.DefaultEvalNumberLiteral;
    pub const evalNumberLiteral = comath.ctx.defaultEvalNumberLiteral;

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

    pub fn EvalBinOp(comptime Lhs: type, comptime op: []const u8, comptime Rhs: type) type {
        const lhs_undef: Lhs = undefined;
        const rhs_undef: Rhs = undefined;
        return switch (@field(Op, op)) {
            .@"+" => @TypeOf(lhs_undef.add(rhs_undef)),
            .@"-" => @TypeOf(lhs_undef.sub(rhs_undef)),
            .@"*" => @TypeOf(lhs_undef.mul(rhs_undef)),
            .@"/" => @TypeOf(lhs_undef.div(rhs_undef)),
        };
    }

    pub fn evalBinOp(_: ComputeContext, lhs: anytype, comptime op: []const u8, rhs: anytype) !EvalBinOp(@TypeOf(lhs), op, @TypeOf(rhs)) {
        return switch (@field(Op, op)) {
            .@"+" => lhs.add(rhs),
            .@"-" => lhs.sub(rhs),
            .@"*" => lhs.mul(rhs),
            .@"/" => lhs.div(rhs),
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
}
