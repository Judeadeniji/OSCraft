//! OSCraft — CLI kexec Stage Command Module
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const zli = @import("zli");
const kexec = @import("../boot/kexec.zig");

pub fn register(init_options: zli.InitOptions) !*zli.Command {
    const cmd = try zli.Command.init(init_options, .{
        .name = "kexec-stage",
        .description = "Plan instant zero-reboot OS jump using kexec without hardware reboot",
    }, execute);

    try cmd.addPositionalArg(.{
        .name = "kernel",
        .description = "Path to kernel image (vmlinuz)",
        .required = true,
    });

    try cmd.addPositionalArg(.{
        .name = "initrd",
        .description = "Path to initial ramdisk image (initrd/initramfs)",
        .required = true,
    });

    try cmd.addFlag(.{
        .name = "cmdline",
        .shortcut = "c",
        .description = "Kernel commandline arguments (must include live/toram flag)",
        .type = .String,
        .default_value = .{ .String = "toram quiet splash" },
    });

    return cmd;
}

pub fn execute(ctx: zli.CommandContext) !void {
    const kernel = ctx.getArg("kernel") orelse return error.MissingKernelArgument;
    const initrd = ctx.getArg("initrd") orelse return error.MissingInitrdArgument;
    const cmdline = ctx.flag("cmdline", []const u8);

    const plan = kexec.KexecStagePlan{
        .kernel_path = kernel,
        .initrd_path = initrd,
        .cmdline = cmdline,
    };

    try plan.validate();

    const load_args = try plan.buildLoadArgs(ctx.allocator);
    defer {
        ctx.allocator.free(load_args[3]);
        ctx.allocator.free(load_args[4]);
        ctx.allocator.free(load_args);
    }

    try ctx.writer.print("Staging Plan for Zero-Reboot kexec:\n", .{});
    try ctx.writer.print("1. Load command: ", .{});
    for (load_args, 0..) |arg, i| {
        if (i > 0) try ctx.writer.print(" ", .{});
        try ctx.writer.print("{s}", .{arg});
    }
    try ctx.writer.print("\n", .{});

    try ctx.writer.print("2. Execute jump: kexec -e\n", .{});
}
