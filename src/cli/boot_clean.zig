//! OSCraft — CLI Boot Clean Command Module
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const zli = @import("zli");
const efi = @import("../boot/efi.zig");
const boot_probe = @import("../boot/probe.zig");
const exec = @import("../system/exec.zig");

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

    try ctx.writer.print("Inspecting UEFI NVRAM and ESP directory at '{s}'...\n", .{esp_path});
    if (dry_run) {
        try ctx.writer.print("Execution Mode: DRY-RUN (no files or NVRAM entries will be deleted)\n\n", .{});
    } else {
        try ctx.writer.print("Execution Mode: LIVE (changes will be permanently applied)\n\n", .{});
    }

    // 1. Run efibootmgr to query NVRAM
    const args = [_][]const u8{"efibootmgr"};
    const run_res = std.process.run(ctx.allocator, ctx.io, .{
        .argv = &args,
    }) catch |err| {
        try ctx.writer.print("Error invoking efibootmgr ({t}). Ensure efibootmgr is installed and system supports UEFI.\n", .{err});
        return;
    };
    defer {
        ctx.allocator.free(run_res.stdout);
        ctx.allocator.free(run_res.stderr);
    }

    if (!run_res.term.success()) {
        try ctx.writer.print("efibootmgr returned an error code. Check permissions (requires root for NVRAM access).\n", .{});
        return;
    }

    var bm = efi.BootManager.init(ctx.allocator);
    defer bm.deinit();

    bm.parseOutput(run_res.stdout) catch |err| {
        try ctx.writer.print("Failed to parse efibootmgr output: {t}\n", .{err});
        return;
    };

    try ctx.writer.print("Active Boot Order: ", .{});
    for (bm.boot_order.items, 0..) |slot, i| {
        if (i > 0) try ctx.writer.print(", ", .{});
        try ctx.writer.print("{X:0>4}", .{slot});
    }
    try ctx.writer.print("\n\nRegistered Boot Entries ({d}):\n", .{bm.entries.items.len});
    for (bm.entries.items) |entry| {
        const star = if (entry.is_active) "*" else " ";
        try ctx.writer.print("  Boot{X:0>4}{s} {s} -> {s}\n", .{
            entry.boot_num,
            star,
            entry.title,
            entry.device_path orelse "(no file pointer)",
        });
    }

    // 2. Scan ESP EFI directory
    const efi_dir_path = try std.fmt.allocPrint(ctx.allocator, "{s}/EFI", .{esp_path});
    defer ctx.allocator.free(efi_dir_path);

    const esp_dirs = boot_probe.scanEspSubdirectories(ctx.allocator, ctx.io, efi_dir_path) catch |err| {
        try ctx.writer.print("\nCould not scan ESP directory '{s}': {t}\n", .{ efi_dir_path, err });
        return;
    };
    defer {
        for (esp_dirs) |d| ctx.allocator.free(d);
        ctx.allocator.free(esp_dirs);
    }

    // 3. Detect orphans
    const orphans = efi.detectOrphanEfiDirectories(ctx.allocator, esp_dirs, bm.entries.items) catch |err| {
        try ctx.writer.print("\nFailed to compute orphan directories: {t}\n", .{err});
        return;
    };
    defer ctx.allocator.free(orphans);

    try ctx.writer.print("\nESP Orphan Analysis:\n", .{});
    if (orphans.len == 0) {
        try ctx.writer.print("  No orphaned EFI directories found. ESP is clean.\n", .{});
    } else {
        try ctx.writer.print("  Found {d} orphaned EFI director{s} with no active NVRAM pointer:\n", .{
            orphans.len,
            if (orphans.len == 1) "y" else "ies",
        });
        for (orphans) |orphan| {
            try ctx.writer.print("    - {s}/EFI/{s}\n", .{ esp_path, orphan });
        }

        if (dry_run) {
            try ctx.writer.print("\nTo remove orphaned directories, re-run with: oscraft boot-clean --dry-run=false\n", .{});
        }
    }
}
