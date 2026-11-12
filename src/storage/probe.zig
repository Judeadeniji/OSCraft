//! OSCraft — Storage Engine: Live Disk Probing & Topology Discovery
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const disk = @import("disk.zig");

const Io = std.Io;

pub const ProbeError = error{
    InvalidDiskDump,
    MissingSectorSize,
    MissingDeviceField,
    PartitionParseFailed,
    SysfsDiskNotFound,
};

/// Filters block device directory names, returning true for real physical drives.
/// Filters out loopback devices, ramdisks, and virtual device mapper nodes.
pub fn isPhysicalDisk(name: []const u8) bool {
    if (std.mem.startsWith(u8, name, "loop")) return false;
    if (std.mem.startsWith(u8, name, "ram")) return false;
    if (std.mem.startsWith(u8, name, "zram")) return false;
    if (std.mem.startsWith(u8, name, "dm-")) return false;
    if (std.mem.startsWith(u8, name, "sr")) return false; // optical drives
    return true;
}

/// Helper to read a number from a sysfs attribute file.
pub fn readSysfsNumber(io: Io, path: []const u8) ?u64 {
    var file = Io.Dir.openFileAbsolute(io, path, .{}) catch return null;
    defer file.close(io);

    var buf: [64]u8 = undefined;
    const n = file.readPositionalAll(io, &buf, 0) catch return null;
    const str = std.mem.trim(u8, buf[0..n], " \r\n\t");
    return std.fmt.parseInt(u64, str, 10) catch null;
}

/// Reads Linux kernel /sys/block/<disk_name> directly without requiring root permissions.
/// Populates and returns a Disk struct with its partitions discovered from sysfs.
pub fn probeFromSysfs(allocator: std.mem.Allocator, io: Io, disk_name_or_path: []const u8) !disk.Disk {
    var raw_name = disk_name_or_path;
    if (std.mem.startsWith(u8, raw_name, "/dev/")) {
        raw_name = raw_name["/dev/".len..];
    }

    const sys_disk_dir_path = try std.fmt.allocPrint(allocator, "/sys/block/{s}", .{raw_name});
    defer allocator.free(sys_disk_dir_path);

    var disk_dir = Io.Dir.openDirAbsolute(io, sys_disk_dir_path, .{ .iterate = true }) catch |err| {
        if (err == error.FileNotFound) return error.SysfsDiskNotFound;
        return err;
    };
    defer disk_dir.close(io);

    // 1. Read total capacity in sectors
    const size_path = try std.fmt.allocPrint(allocator, "{s}/size", .{sys_disk_dir_path});
    defer allocator.free(size_path);
    const total_sectors = readSysfsNumber(io, size_path) orelse 0;

    // 2. Read hardware sector size
    const sec_size_path = try std.fmt.allocPrint(allocator, "{s}/queue/hw_sector_size", .{sys_disk_dir_path});
    defer allocator.free(sec_size_path);
    const sector_size = readSysfsNumber(io, sec_size_path) orelse 512;

    // 3. Enumerate child partitions in /sys/block/<disk>/
    var partitions_list = std.ArrayListUnmanaged(disk.Partition).empty;
    errdefer partitions_list.deinit(allocator);

    var iter = disk_dir.iterate();
    while (try iter.next(io)) |entry| {
        if (entry.kind == .directory and std.mem.startsWith(u8, entry.name, raw_name)) {
            // Must have a "partition" or "start" file to be a real partition
            const part_start_path = try std.fmt.allocPrint(allocator, "{s}/{s}/start", .{ sys_disk_dir_path, entry.name });
            defer allocator.free(part_start_path);

            const part_size_path = try std.fmt.allocPrint(allocator, "{s}/{s}/size", .{ sys_disk_dir_path, entry.name });
            defer allocator.free(part_size_path);

            if (readSysfsNumber(io, part_start_path)) |start_sec| {
                if (readSysfsNumber(io, part_size_path)) |size_sec| {
                    if (size_sec > 0) {
                        const node_str = try std.fmt.allocPrint(allocator, "/dev/{s}", .{entry.name});
                        const part_name = node_str["/dev/".len..];

                        try partitions_list.append(allocator, .{
                            .name = part_name,
                            .node = node_str,
                            .part_num = @intCast(partitions_list.items.len + 1),
                            .start_sector = start_sec,
                            .size_sectors = size_sec,
                            .size_bytes = size_sec * sector_size,
                        });
                    }
                }
            }
        }
    }

    const dev_node = try std.fmt.allocPrint(allocator, "/dev/{s}", .{raw_name});

    return disk.Disk{
        .allocator = allocator,
        .name = dev_node,
        .node = dev_node,
        .model = "Linux Block Device",
        .size_sectors = total_sectors,
        .size_bytes = total_sectors * sector_size,
        .partitions = partitions_list,
        .gaps = .empty,
    };
}

/// Parses the standard Linux `sfdisk -d` output dump format.
/// Returns a fully populated Disk struct with its partitions parsed.
pub fn parseSfdiskDump(allocator: std.mem.Allocator, dump: []const u8) !disk.Disk {
    var device_name: []const u8 = "";
    var total_sectors: u64 = 0;
    var sector_size: u64 = 512;

    var partitions_list = std.ArrayListUnmanaged(disk.Partition).empty;
    errdefer partitions_list.deinit(allocator);

    var lines = std.mem.splitScalar(u8, dump, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \r\t");
        if (line.len == 0) continue;

        // Header lines, e.g. "device: /dev/sda"
        if (std.mem.startsWith(u8, line, "device:")) {
            const val = std.mem.trim(u8, line["device:".len..], " \t");
            device_name = try allocator.dupe(u8, val);
            continue;
        }

        if (std.mem.startsWith(u8, line, "sector-size:")) {
            const val = std.mem.trim(u8, line["sector-size:".len..], " \t");
            sector_size = std.fmt.parseInt(u64, val, 10) catch 512;
            continue;
        }

        if (std.mem.startsWith(u8, line, "last-lba:")) {
            const val = std.mem.trim(u8, line["last-lba:".len..], " \t");
            const last_lba = std.fmt.parseInt(u64, val, 10) catch 0;
            if (last_lba > 0) {
                total_sectors = last_lba + 34; // Add backup GPT sectors
            }
            continue;
        }

        // Partition lines, e.g. "/dev/sda1 : start= 2048, size= 1048576, type=..."
        if (std.mem.indexOfScalar(u8, line, ':')) |colon_idx| {
            const node = std.mem.trim(u8, line[0..colon_idx], " \t");
            if (node.len == 0 or !std.mem.startsWith(u8, node, "/dev/")) continue;

            const rest = line[colon_idx + 1 ..];
            var part_start: u64 = 0;
            var part_size: u64 = 0;

            var tokens = std.mem.splitScalar(u8, rest, ',');
            while (tokens.next()) |token| {
                const trimmed_token = std.mem.trim(u8, token, " \t");
                if (std.mem.startsWith(u8, trimmed_token, "start=")) {
                    const num_str = std.mem.trim(u8, trimmed_token["start=".len..], " \t");
                    part_start = std.fmt.parseInt(u64, num_str, 10) catch 0;
                } else if (std.mem.startsWith(u8, trimmed_token, "size=")) {
                    const num_str = std.mem.trim(u8, trimmed_token["size=".len..], " \t");
                    part_size = std.fmt.parseInt(u64, num_str, 10) catch 0;
                }
            }

            if (part_size > 0) {
                const node_dupe = try allocator.dupe(u8, node);
                var part_name = node_dupe;
                if (std.mem.lastIndexOfScalar(u8, node_dupe, '/')) |idx| {
                    part_name = node_dupe[idx + 1 ..];
                }

                try partitions_list.append(allocator, .{
                    .name = part_name,
                    .node = node_dupe,
                    .part_num = @intCast(partitions_list.items.len + 1),
                    .start_sector = part_start,
                    .size_sectors = part_size,
                    .size_bytes = part_size * sector_size,
                });
            }
        }
    }

    if (device_name.len == 0) {
        device_name = try allocator.dupe(u8, "/dev/unknown");
    }

    return disk.Disk{
        .allocator = allocator,
        .name = device_name,
        .node = device_name,
        .model = "Generic Storage Device",
        .size_sectors = total_sectors,
        .size_bytes = total_sectors * sector_size,
        .partitions = partitions_list,
        .gaps = .empty,
    };
}

/// Frees memory allocated by parseSfdiskDump or probeFromSysfs for Disk.
pub fn freeDisk(d: *disk.Disk) void {
    d.allocator.free(d.node);
    for (d.partitions.items) |p| {
        d.allocator.free(p.node);
    }
    d.deinit();
}
