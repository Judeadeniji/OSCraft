//! OSCraft — CLI Scan Command Module
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const zli = @import("zli");
const disk = @import("../storage/disk.zig");
const probe = @import("../storage/probe.zig");

const Io = std.Io;

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

    if (disk_name.len == 0) {
        try ctx.writer.print("Scanning available storage block devices in /sys/block...\n\n", .{});

        var sys_block = Io.Dir.openDirAbsolute(ctx.io, "/sys/block", .{ .iterate = true }) catch {
            try ctx.writer.print("Error: Unable to access /sys/block on this system.\n", .{});
            return;
        };
        defer sys_block.close(ctx.io);

        var iter = sys_block.iterate();
        var found_any = false;

        while (try iter.next(ctx.io)) |entry| {
            if (probe.isPhysicalDisk(entry.name)) {
                found_any = true;
                try ctx.writer.print("Physical Block Device: /dev/{s}\n", .{entry.name});
                try scanSingleDisk(ctx, entry.name);
                try ctx.writer.print("\n", .{});
            }
        }

        if (!found_any) {
            try ctx.writer.print("No physical disk drives detected.\n", .{});
        }
    } else {
        try scanSingleDisk(ctx, disk_name);
    }
}

fn scanSingleDisk(ctx: zli.CommandContext, disk_name: []const u8) !void {
    const dev_path = if (std.mem.startsWith(u8, disk_name, "/dev/"))
        disk_name
    else
        try std.fmt.allocPrint(ctx.allocator, "/dev/{s}", .{disk_name});
    defer if (!std.mem.startsWith(u8, disk_name, "/dev/")) ctx.allocator.free(dev_path);

    try ctx.writer.print("Target Disk: {s}\n", .{dev_path});

    // Run sfdisk -d to get exact kernel partition table
    const sfdisk_args = [_][]const u8{ "sfdisk", "-d", dev_path };
    const run_res = std.process.run(ctx.allocator, ctx.io, .{
        .argv = &sfdisk_args,
    }) catch |err| {
        try ctx.writer.print("  Unable to query partition table ({t}). Check permissions or disk node.\n", .{err});
        return;
    };
    defer {
        ctx.allocator.free(run_res.stdout);
        ctx.allocator.free(run_res.stderr);
    }

    if (!run_res.term.success()) {
        try ctx.writer.print("  sfdisk returned non-zero code. Disk may be unformatted or unpartitioned.\n", .{});
        return;
    }

    var parsed_disk = probe.parseSfdiskDump(ctx.allocator, run_res.stdout) catch |err| {
        try ctx.writer.print("  Failed to parse disk layout ({t}).\n", .{err});
        return;
    };
    defer probe.freeDisk(&parsed_disk);

    try ctx.writer.print("  Total Capacity: {d:.2} GiB ({d} sectors)\n", .{
        parsed_disk.totalGiB(),
        parsed_disk.size_sectors,
    });

    try ctx.writer.print("  Partitions ({d}):\n", .{parsed_disk.partitions.items.len});
    for (parsed_disk.partitions.items) |part| {
        try ctx.writer.print("    - {s}: sectors {d}..{d} ({d:.2} GiB)\n", .{
            part.name,
            part.start_sector,
            part.endSector(),
            part.sizeGiB(),
        });
    }

    // Calculate unallocated gaps
    parsed_disk.calculateGaps() catch |err| {
        try ctx.writer.print("  Failed to calculate unallocated gaps: {t}\n", .{err});
        return;
    };

    if (parsed_disk.gaps.items.len == 0) {
        try ctx.writer.print("  Unallocated Gaps: None (Disk fully allocated)\n", .{});
    } else {
        try ctx.writer.print("  Unallocated Gaps ({d}):\n", .{parsed_disk.gaps.items.len});
        for (parsed_disk.gaps.items, 0..) |gap, i| {
            const align_str = if (gap.is_aligned) "1 MiB aligned" else "unaligned";
            try ctx.writer.print("    [{d}] sectors {d}..{d} -> {d:.2} GiB ({s})\n", .{
                i + 1,
                gap.start_sector,
                gap.end_sector,
                gap.sizeGiB(),
                align_str,
            });
        }
    }
}
