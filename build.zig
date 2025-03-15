const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const embed: []const []const u8 = &.{"static/index.html"};
    const migrations: []const []const u8 = &.{
        "migrations/00001.initial.up.sql",
        "migrations/00002.application.up.sql",
    };

    const tk = b.dependency("tokamak", .{ .embed = embed, .target = target, .optimize = optimize });
    const tokamak = tk.module("tokamak");
    const hz = tk.builder.dependency("httpz", .{ .target = target, .optimize = optimize });
    const httpz = hz.module("httpz");
    const metrics = hz.builder.dependency("metrics", .{ .target = target, .optimize = optimize }).module("metrics");
    const zmpl = b.dependency("zmpl", .{ .target = target, .optimize = optimize }).module("zmpl");
    const pg = b.dependency("pg", .{ .target = target, .optimize = optimize }).module("pg");
    const klib = b.dependency("klib", .{ .target = target, .optimize = optimize }).module("klib");
    const uuid = b.dependency("uuid", .{ .target = target, .optimize = optimize }).module("uuid");

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_mod.addImport("tokamak", tokamak);
    lib_mod.addImport("metrics", metrics);
    lib_mod.addImport("httpz", httpz);
    lib_mod.addImport("zmpl", zmpl);
    lib_mod.addImport("pg", pg);
    lib_mod.addImport("klib", klib);
    lib_mod.addImport("uuid", uuid);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.addImport("kauth_lib", lib_mod);
    exe_mod.addImport("tokamak", tokamak);
    exe_mod.addImport("metrics", metrics);
    exe_mod.addImport("httpz", httpz);
    exe_mod.addImport("zmpl", zmpl);
    exe_mod.addImport("pg", pg);
    exe_mod.addImport("klib", klib);
    exe_mod.addImport("uuid", uuid);

    try embedMigrations(b, exe_mod, @alignCast(migrations));

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "kauth",
        .root_module = lib_mod,
    });

    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "kauth",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}

fn embedMigrations(b: *std.Build, root: *std.Build.Module, files: []const []const u8) !void {
    const options = b.addOptions();
    root.addOptions("migrations", options);

    const contents = try b.allocator.alloc([]const u8, files.len);
    for (files, 0..) |path, i| {
        errdefer |e| {
            if (e == error.FileNotFound) {
                std.log.err("File not found: {s}", .{path});
            }
        }

        contents[i] = try std.fs.cwd().readFileAlloc(
            b.allocator,
            path,
            std.math.maxInt(u32),
        );
    }

    options.addOption([]const []const u8, "files", files);
    options.addOption([]const []const u8, "contents", contents);
}
