//! OSCraft — CLI Scan Command Module
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const zli = @import("zli");
const disk = @import("../storage/disk.zig");

pub fn register(init_options: zli.InitOptions) !*zli.Command {
    const cmd = try zli.Command.init(init_options, .{
        .name = "scan",
        .description = "Inspect physical disk topology and calculate unallocated gaps",
    }, execute);

    try cmd.addFlag(.{
        .name = "disk",
        .shortcut = "d",
        .description = "Target block device name (e.g. sda or nvme0n1)",
        .type = .String,
        .default_value = .{ .String = "" },
    });

    return cmd;
}

pub fn execute(ctx: zli.CommandContext) !void {
    const disk_name = ctx.flag("disk", []const u8);

    if (disk_name.len > 0) {
        try ctx.writer.print("Inspecting block device: /dev/{s}\n", .{disk_name});
        try ctx.writer.print("Target device topology analysis initialized.\n", .{});
    } else {
        try ctx.writer.print("Scanning available storage block devices for unallocated gaps...\n", .{});
        try ctx.writer.print("Pass '--disk=<name>' to inspect a specific block device.\n", .{});
    }
}
