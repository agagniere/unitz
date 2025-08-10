const std = @import("std");

const NAME = "unitz";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const comath = b.dependency("comath", .{}).module("comath");

    const unitz = b.addModule(NAME, .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    unitz.addImport("comath", comath);

    { // Test
        const test_step = b.step("test", "Run unit tests");
        const lib_unit_tests = b.addTest(.{ .root_module = unitz });
        test_step.dependOn(&b.addRunArtifact(lib_unit_tests).step);
    }

    { // Documentation
        const docs_step = b.step("docs", "Build the project documentation");

        const docs_obj = b.addObject(.{
            .name = NAME,
            .root_module = unitz,
        });

        const install_docs = b.addInstallDirectory(.{
            .source_dir = docs_obj.getEmittedDocs(),
            .install_dir = .prefix,
            .install_subdir = "docs",
        });
        docs_step.dependOn(&install_docs.step);
    }
}
