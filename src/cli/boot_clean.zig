//! OSCraft — CLI Boot Clean Command Module
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const zli = @import("zli");
const efi = @import("../boot/efi.zig");

pub fn register(init_options: zli.InitOptions) !*zli.Command {
    const cmd = try zli.Command.init(init_options, .{
        .name = "boot-clean",
        .description = "Inspect UEFI NVRAM and ESP directories for orphaned boot entries",
    }, execute);

    try cmd.addFlag(.{
        .name = "esp",
        .shortcut = "e",
        .description = "Path to EFI System Partition mountpoint",
        .type = .String,
        .default_value = .{ .String = "/boot/efi" },
    });

    try cmd.addFlag(.{
        .name = "dry-run",
        .shortcut = "n",
        .description = "Simulate operations without deleting NVRAM entries or EFI files",
        .type = .Bool,
        .default_value = .{ .Bool = true },
    });

    return cmd;
}

pub fn execute(ctx: zli.CommandContext) !void {
    const esp_path = ctx.flag("esp", []const u8);
    const dry_run = ctx.flag("dry-run", bool);

    try ctx.writer.print("Inspecting UEFI boot entries and ESP at '{s}'...\n", .{esp_path});
    if (dry_run) {
        try ctx.writer.print("Mode: Dry-run simulation enabled (no changes will be applied).\n", .{});
    } else {
        try ctx.writer.print("Mode: Live execution enabled.\n", .{});
    }
}
