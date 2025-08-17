const std = @import("std");
const builtin = @import("builtin");

const min_zig = std.SemanticVersion.parse("0.14.0") catch unreachable;
const max_zig = std.SemanticVersion.parse("0.14.1") catch unreachable;

pub fn build(b: *std.Build) void {
    comptime {
        if (builtin.zig_version.order(min_zig) == .lt) {
            @compileError(std.fmt.comptimePrint(
                "Your Zig version v{} does not meet the minimum build requirement of v{}",
                .{ builtin.zig_version, min_zig },
            ));
        }
        if (builtin.zig_version.order(max_zig) == .gt) {
            @compileError(std.fmt.comptimePrint(
                "Your Zig version v{} does not meet the maximum build requirement of v{}",
                .{ builtin.zig_version, max_zig },
            ));
        }
    }

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "todo_zen",
        .root_module = exe_mod,
        .use_llvm = optimize != .Debug,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
