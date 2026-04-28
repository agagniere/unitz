const std = @import("std");

const samples = [_][]const u8{
    "error_to_incompatible_units",
    "error_to_invalid_destination",
    "error_to_storage_mismatch",
    "error_from_invalid_source",
    "error_from_storage_mismatch",
    "error_mul_invalid_argument",
    "error_div_invalid_argument",
    "error_sqrt_odd_dimension",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const unitz = b.dependency("unitz", .{ .target = target, .optimize = optimize }).module("unitz");

    for (samples) |name| {
        const exe = b.addExecutable(.{
            .name = name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(b.fmt("{s}.zig", .{name})),
                .target = target,
                .optimize = optimize,
            }),
        });
        exe.root_module.addImport("unitz", unitz);

        const step = b.step(name, b.fmt("Compile {s}.zig (expected to fail)", .{name}));
        step.dependOn(&exe.step);
    }
}
