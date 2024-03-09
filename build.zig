const std = @import("std");

pub fn build(b: *std.Build) void {
    const root_source_file = std.Build.LazyPath.relative("src/lib.zig");

    // Dependencies
    const datetime_dep = b.dependency("datetime", .{});
    const datetime_mod = datetime_dep.module("datetime");

    // Module
    const cookie_mod = b.addModule("cookie", .{ .root_source_file = root_source_file });
    cookie_mod.addImport("datetime", datetime_mod);

    // Library
    const lib_step = b.step("lib", "Install library");

    const lib = b.addStaticLibrary(.{
        .name = "cookie",
        .root_source_file = root_source_file,
        .target = b.standardTargetOptions(.{}),
        .optimize = b.standardOptimizeOption(.{}),
        .version = .{ .major = 0, .minor = 1, .patch = 0 },
    });
    lib.root_module.addImport("datetime", datetime_mod);

    const lib_install = b.addInstallArtifact(lib, .{});
    lib_step.dependOn(&lib_install.step);
    b.default_step.dependOn(lib_step);

    // Docs
    const docs_step = b.step("docs", "Emit docs");

    const docs_install = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    docs_step.dependOn(&docs_install.step);
    b.default_step.dependOn(docs_step);

    // Tests
    const tests_step = b.step("test", "Run tests");

    const tests = b.addTest(.{
        .root_source_file = root_source_file,
    });
    tests.root_module.addImport("datetime", datetime_mod);

    const tests_run = b.addRunArtifact(tests);
    tests_step.dependOn(&tests_run.step);
    b.default_step.dependOn(tests_step);

    // Code coverage
    const cov_step = b.step("cov", "Generate code coverage report");

    const cov_run = b.addSystemCommand(&.{ "kcov", "--clean", "--include-pattern=src/", "kcov-output" });
    cov_run.addArtifactArg(tests);

    cov_step.dependOn(&cov_run.step);
    b.default_step.dependOn(cov_step);

    // Lints
    const lints_step = b.step("lint", "Run lints");

    const lints = b.addFmt(.{
        .paths = &.{ "src", "build.zig" },
        .check = true,
    });

    lints_step.dependOn(&lints.step);
    b.default_step.dependOn(lints_step);
}
