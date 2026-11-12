//! OSCraft — CLI Interface Engine
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const zli = @import("zli");

const scan_cmd = @import("scan.zig");
const expand_cmd = @import("expand.zig");
const boot_clean_cmd = @import("boot_clean.zig");
const kexec_stage_cmd = @import("kexec_stage.zig");
const loopback_gen_cmd = @import("loopback_gen.zig");

pub const scan = scan_cmd;
pub const expand = expand_cmd;
pub const boot_clean = boot_clean_cmd;
pub const kexec_stage = kexec_stage_cmd;
pub const loopback_gen = loopback_gen_cmd;

pub fn initCli(init_options: zli.InitOptions) !*zli.Command {
    const root = try zli.Command.init(init_options, .{
        .name = "oscraft",
        .description = "Live dynamic partitioning, UEFI hygiene, and zero-reboot OS switcher",
        .version = .{ .major = 0, .minor = 1, .patch = 0, .pre = null, .build = null },
    }, handleRoot);

    try root.addFlag(.{
        .name = "verbose",
        .shortcut = "v",
        .description = "Enable verbose output logging",
        .type = .Bool,
        .default_value = .{ .Bool = false },
        .persistent = true,
    });

    // Register modular subcommands
    try root.addCommand(try scan_cmd.register(init_options));
    try root.addCommand(try expand_cmd.register(init_options));
    try root.addCommand(try boot_clean_cmd.register(init_options));
    try root.addCommand(try kexec_stage_cmd.register(init_options));
    try root.addCommand(try loopback_gen_cmd.register(init_options));

    return root;
}

fn handleRoot(ctx: zli.CommandContext) !void {
    try ctx.writer.print("OSCraft: Live dynamic partitioning, boot hygiene, and zero-reboot kexec\n\n", .{});
    try ctx.command.printHelp();
}
