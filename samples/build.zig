const std = @import("std");

const error_samples = [_][]const u8{
    "error_to_incompatible_units",
    "error_to_invalid_destination",
    "error_to_storage_mismatch",
    "error_from_invalid_source",
    "error_from_storage_mismatch",
    "error_from_incompatible_units",
    "error_mul_invalid_argument",
    "error_div_invalid_argument",
    "error_sqrt_odd_dimension",
};

const examples = [_][]const u8{
    "example_aircraft_speed",
    "example_body_mass_index",
    "example_impulse",
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const unitz = b.dependency("unitz", .{ .target = target, .optimize = optimize }).module("unitz");

    for (error_samples) |name| {
        const exe = addExe(b, name, unitz, target, optimize);
        const step = b.step(name, b.fmt("Compile {s}.zig (expected to fail)", .{name}));
        step.dependOn(&exe.step);
    }

    for (examples) |name| {
        const exe = addExe(b, name, unitz, target, optimize);
        b.installArtifact(exe);
        const run = b.addRunArtifact(exe);
        const step = b.step(name, b.fmt("Run {s}.zig", .{name}));
        step.dependOn(&run.step);
    }
}

fn addExe(
    b: *std.Build,
    name: []const u8,
    unitz: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .root_source_file = b.path(b.fmt("{s}.zig", .{name})),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("unitz", unitz);
    return exe;
}
