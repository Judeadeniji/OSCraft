//! OSCraft — CLI Live Storage Expansion Command Module
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const zli = @import("zli");
const disk = @import("../storage/disk.zig");
const btrfs = @import("../storage/btrfs.zig");
const expand = @import("../storage/expand.zig");
const probe = @import("../storage/probe.zig");
const exec = @import("../system/exec.zig");
const safety = @import("../system/safety.zig");

pub fn register(init_options: zli.InitOptions) !*zli.Command {
    const cmd = try zli.Command.init(init_options, .{
        .name = "expand",
        .description = "Dynamically expand live Btrfs root from unallocated space without rebooting",
    }, execute);

    try cmd.addFlag(.{
        .name = "disk",
        .shortcut = "d",
        .description = "Target block device name (e.g. sda or nvme0n1)",
        .type = .String,
        .default_value = .{ .String = "" },
    });

    try cmd.addFlag(.{
        .name = "mount",
        .shortcut = "m",
        .description = "Target Btrfs mountpoint to expand",
        .type = .String,
        .default_value = .{ .String = "/" },
    });

    try cmd.addFlag(.{
        .name = "size",
        .shortcut = "s",
        .description = "Desired expansion size (e.g. 50G, 100GiB; leave empty for entire gap)",
        .type = .String,
        .default_value = .{ .String = "" },
    });

    try cmd.addFlag(.{
        .name = "dry-run",
        .shortcut = "n",
        .description = "Simulate operations without modifying partitions or filesystem",
        .type = .Bool,
        .default_value = .{ .Bool = true },
    });

    return cmd;
}

pub fn execute(ctx: zli.CommandContext) !void {
    const disk_name = ctx.flag("disk", []const u8);
    const mount_point = ctx.flag("mount", []const u8);
    const size_str = ctx.flag("size", []const u8);
    const dry_run = ctx.flag("dry-run", bool);

    if (disk_name.len == 0) {
        try ctx.writer.print("Error: Target disk must be specified via --disk=<name> (e.g. --disk=sda).\n", .{});
        return;
    }

    const dev_path = if (std.mem.startsWith(u8, disk_name, "/dev/"))
        disk_name
    else
        try std.fmt.allocPrint(ctx.allocator, "/dev/{s}", .{disk_name});
    defer if (!std.mem.startsWith(u8, disk_name, "/dev/")) ctx.allocator.free(dev_path);

    try ctx.writer.print("Initiating Live Storage Expansion for mount '{s}' on {s}...\n", .{ mount_point, dev_path });
    if (dry_run) {
        try ctx.writer.print("Execution Mode: DRY-RUN (simulating partition creation and Btrfs pooling)\n\n", .{});
    } else {
        try ctx.writer.print("Execution Mode: LIVE (changes will be applied to disk without rebooting)\n\n", .{});
    }

    // 1. Probe target disk
    var maybe_disk: ?disk.Disk = probe.probeFromSysfs(ctx.allocator, ctx.io, dev_path) catch null;
    if (maybe_disk == null) {
        const sfdisk_args = [_][]const u8{ "sfdisk", "-d", dev_path };
        const run_res = std.process.run(ctx.allocator, ctx.io, .{ .argv = &sfdisk_args }) catch |err| {
            try ctx.writer.print("Error querying disk layout: {t}\n", .{err});
            return;
        };
        defer {
            ctx.allocator.free(run_res.stdout);
            ctx.allocator.free(run_res.stderr);
        }
        if (run_res.term.success()) {
            maybe_disk = probe.parseSfdiskDump(ctx.allocator, run_res.stdout) catch null;
        }
    }

    if (maybe_disk == null) {
        try ctx.writer.print("Error: Unable to inspect disk topology on {s}.\n", .{dev_path});
        return;
    }

    var probed_disk = maybe_disk.?;
    defer probe.freeDisk(&probed_disk);

    // 2. Discover unallocated gaps
    try probed_disk.calculateGaps();
    if (probed_disk.gaps.items.len == 0) {
        try ctx.writer.print("Error: No unallocated gaps found on {s}. Disk is fully partitioned.\n", .{dev_path});
        return;
    }

    // 3. Parse requested size if provided
    var requested_bytes: ?u64 = null;
    if (size_str.len > 0) {
        requested_bytes = btrfs.parseHumanSize(size_str);
        if (requested_bytes == null) {
            try ctx.writer.print("Error: Invalid size format '{s}'. Expected format like 50G, 100GiB, or 2048M.\n", .{size_str});
            return;
        }
    }

    // 4. Construct the live expansion plan
    const plan = expand.planLiveBtrfsExpansion(ctx.allocator, probed_disk, mount_point, requested_bytes) catch |err| {
        try ctx.writer.print("Error: Failed to plan live expansion: {t}\n", .{err});
        return;
    };
    defer ctx.allocator.free(plan.new_part_node);

    try ctx.writer.print("Plan Summary:\n", .{});
    try ctx.writer.print("  Target Disk:       {s}\n", .{plan.disk_node});
    try ctx.writer.print("  New Partition:     {s} (Partition #{d})\n", .{ plan.new_part_node, plan.new_part_num });
    try ctx.writer.print("  Allocated Space:   {d:.2} GiB ({d} sectors)\n", .{ plan.sizeGiB(), plan.size_sectors });
    try ctx.writer.print("  Sector Range:      {d}..{d}\n", .{ plan.start_sector, plan.endSector() });
    try ctx.writer.print("  Sector Alignment:  {s}\n", .{if (plan.is_aligned) "1 MiB aligned (OK)" else "unaligned"});
    try ctx.writer.print("  Target Mountpoint: {s}\n\n", .{plan.mount_point});

    const create_args = try plan.buildPartitionCreateArgs(ctx.allocator);
    defer {
        ctx.allocator.free(create_args[1]);
        ctx.allocator.free(create_args[2]);
        ctx.allocator.free(create_args);
    }

    const btrfs_args = try plan.buildBtrfsAddArgs(ctx.allocator);
    defer ctx.allocator.free(btrfs_args);

    if (dry_run) {
        try ctx.writer.print("Simulated Command Sequence:\n", .{});
        try ctx.writer.print("  1. sgdisk {s} {s} {s}\n", .{ create_args[1], create_args[2], create_args[3] });
        try ctx.writer.print("  2. partprobe {s}\n", .{plan.disk_node});
        try ctx.writer.print("  3. btrfs device add -f {s} {s}\n\n", .{ plan.new_part_node, plan.mount_point });
        try ctx.writer.print("To execute this live expansion, re-run with: oscraft expand --disk={s} --dry-run=false\n", .{disk_name});
        return;
    }

    // Live Execution
    var executor = exec.SystemExecutor.init(ctx.allocator, ctx.io, .live);
    defer executor.deinit();

    try ctx.writer.print("Executing Step 1: Creating partition {s}...\n", .{plan.new_part_node});
    executor.dispatch(create_args) catch |err| {
        try ctx.writer.print("Failed to create partition: {t}\n", .{err});
        return;
    };

    try ctx.writer.print("Executing Step 2: Reloading kernel partition table live...\n", .{});
    executor.reloadPartitionTable(plan.disk_node) catch |err| {
        try ctx.writer.print("Failed to reload partition table: {t}\n", .{err});
        return;
    };

    try ctx.writer.print("Executing Step 3: Pooling {s} into live Btrfs root at {s}...\n", .{ plan.new_part_node, plan.mount_point });
    executor.dispatch(btrfs_args) catch |err| {
        try ctx.writer.print("Failed to pool device into Btrfs: {t}\n", .{err});
        return;
    };

    try ctx.writer.print("\nLive filesystem expansion complete! {d:.2} GiB added to {s} without rebooting.\n", .{
        plan.sizeGiB(),
        plan.mount_point,
    });
}
