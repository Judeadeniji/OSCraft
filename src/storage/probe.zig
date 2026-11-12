//! OSCraft — Storage Engine: Live Disk Probing & Topology Discovery
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const disk = @import("disk.zig");

pub const ProbeError = error{
    InvalidDiskDump,
    MissingSectorSize,
    MissingDeviceField,
    PartitionParseFailed,
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

/// Frees memory allocated by parseSfdiskDump for Disk.
pub fn freeDisk(d: *disk.Disk) void {
    d.allocator.free(d.node);
    for (d.partitions.items) |p| {
        d.allocator.free(p.node);
    }
    d.deinit();
}
