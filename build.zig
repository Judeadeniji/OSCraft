const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zli_dep = b.dependency("zli", .{
        .target = target,
        .optimize = optimize,
    });

    const nanoui_dep = b.dependency("nanoui", .{
        .target = target,
        .optimize = optimize,
    });

    const mod = b.addModule("OSCraft", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "zli", .module = zli_dep.module("zli") },
            .{ .name = "nanoui", .module = nanoui_dep.module("nanoui") },
        },
    });

    const exe = b.addExecutable(.{
        .name = "OSCraft",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "OSCraft", .module = mod },
                .{ .name = "zli", .module = zli_dep.module("zli") },
                .{ .name = "nanoui", .module = nanoui_dep.module("nanoui") },
            },
        }),
    });

    b.installArtifact(exe);

    const gui_exe = b.addExecutable(.{
        .name = "oscraft-gui",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/gui_main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "OSCraft", .module = mod },
                .{ .name = "zli", .module = zli_dep.module("zli") },
                .{ .name = "nanoui", .module = nanoui_dep.module("nanoui") },
            },
        }),
    });

    b.installArtifact(gui_exe);

    const run_step = b.step("run", "Run the CLI app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.addPassthruArgs();

    const gui_step = b.step("gui", "Run the native OSCraft GUI");
    const gui_cmd = b.addRunArtifact(gui_exe);
    gui_step.dependOn(&gui_cmd.step);
    gui_cmd.step.dependOn(b.getInstallStep());
    gui_cmd.addPassthruArgs();

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
