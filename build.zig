const std = @import("std");

const NAME = "unitz";
const ROOT_FILE = "src/root.zig";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule(NAME, .{
        .root_source_file = b.path(ROOT_FILE),
        .target = target,
        .optimize = optimize,
    });

    { // Test
        const test_step = b.step("test", "Run unit tests");
        const lib_unit_tests = b.addTest(.{
            .root_source_file = b.path(ROOT_FILE),
            .target = target,
            .optimize = optimize,
        });
        const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
        test_step.dependOn(&run_lib_unit_tests.step);
    }

    { // Documentation
        const docs_step = b.step("docs", "Build the project documentation");

        const docs_obj = b.addObject(.{
            .name = NAME,
            .root_source_file = b.path(ROOT_FILE),
            .target = target,
            .optimize = .Debug,
        });

        const install_docs = b.addInstallDirectory(.{
            .source_dir = docs_obj.getEmittedDocs(),
            .install_dir = .prefix,
            .install_subdir = "docs",
        });
        docs_step.dependOn(&install_docs.step);
    }
}
