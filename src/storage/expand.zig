//! OSCraft — Storage Engine: Live Partition Allocation & Filesystem Expansion
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const disk = @import("disk.zig");
const btrfs = @import("btrfs.zig");

pub const ExpandError = error{
    NoUnallocatedGaps,
    GapTooSmall,
    PartitionLimitReached,
    InvalidPartitionNode,
};

pub const ExpandPlan = struct {
    disk_node: []const u8,
    mount_point: []const u8,
    new_part_num: u32,
    new_part_node: []const u8,
    start_sector: u64,
    size_sectors: u64,
    size_bytes: u64,
    is_aligned: bool,

    pub fn sizeGiB(self: ExpandPlan) f64 {
        return @as(f64, @floatFromInt(self.size_bytes)) / (1024.0 * 1024.0 * 1024.0);
    }

    pub fn endSector(self: ExpandPlan) u64 {
        return self.start_sector + self.size_sectors - 1;
    }

    /// Formats the sgdisk command to create this partition with Linux filesystem type (8300).
    pub fn buildPartitionCreateArgs(self: ExpandPlan, allocator: std.mem.Allocator) ![]const []const u8 {
        const spec_arg = try std.fmt.allocPrint(
            allocator,
            "-n={d}:{d}:{d}",
            .{ self.new_part_num, self.start_sector, self.endSector() },
        );
        errdefer allocator.free(spec_arg);

        const type_arg = try std.fmt.allocPrint(
            allocator,
            "-t={d}:8300",
            .{self.new_part_num},
        );
        errdefer allocator.free(type_arg);

        const args = try allocator.alloc([]const u8, 4);
        args[0] = "sgdisk";
        args[1] = spec_arg;
        args[2] = type_arg;
        args[3] = self.disk_node;

        return args;
    }

    /// Formats the btrfs device add command to pool this new partition live into the target mount.
    pub fn buildBtrfsAddArgs(self: ExpandPlan, allocator: std.mem.Allocator) ![]const []const u8 {
        const args = try allocator.alloc([]const u8, 6);
        args[0] = "btrfs";
        args[1] = "device";
        args[2] = "add";
        args[3] = "-f";
        args[4] = self.new_part_node;
        args[5] = self.mount_point;

        return args;
    }
};

/// Formats partition node name taking NVMe / eMMC 'p' prefix into account.
/// E.g. /dev/sda + 3 -> /dev/sda3
/// E.g. /dev/nvme0n1 + 3 -> /dev/nvme0n1p3
pub fn formatPartitionNode(allocator: std.mem.Allocator, disk_node: []const u8, part_num: u32) ![]const u8 {
    const last_char = disk_node[disk_node.len - 1];
    if (std.ascii.isDigit(last_char)) {
        return std.fmt.allocPrint(allocator, "{s}p{d}", .{ disk_node, part_num });
    } else {
        return std.fmt.allocPrint(allocator, "{s}{d}", .{ disk_node, part_num });
    }
}

/// Discovers the next available partition number on a disk (handles non-sequential partitions).
pub fn findAvailablePartitionNumber(partitions: []const disk.Partition) u32 {
    var max_num: u32 = 0;
    var used: [128]bool = @splat(false);

    for (partitions) |p| {
        if (p.part_num > max_num) max_num = p.part_num;
        if (p.part_num > 0 and p.part_num < used.len) {
            used[p.part_num] = true;
        }
    }

    // Try finding first hole (e.g. if 1, 2, 4, 5 exist, return 3)
    var num: u32 = 1;
    while (num <= max_num) : (num += 1) {
        if (num < used.len and !used[num]) return num;
    }

    return max_num + 1;
}

/// Plans a live Btrfs expansion by selecting an unallocated gap on the disk,
/// enforcing 1 MiB sector alignment, and constructing the ExpandPlan.
pub fn planLiveBtrfsExpansion(
    allocator: std.mem.Allocator,
    d: disk.Disk,
    mount_point: []const u8,
    requested_size_bytes: ?u64,
) !ExpandPlan {
    if (d.gaps.items.len == 0) {
        return error.NoUnallocatedGaps;
    }

    // Find the largest gap
    var best_gap: ?disk.DiskGap = null;
    for (d.gaps.items) |gap| {
        if (best_gap == null or gap.size_sectors > best_gap.?.size_sectors) {
            best_gap = gap;
        }
    }

    const gap = best_gap.?;
    if (gap.size_bytes < (1024 * 1024 * 1024)) { // Must be at least 1 GiB
        return error.GapTooSmall;
    }

    const start_sector = gap.start_sector;
    var alloc_sectors = gap.size_sectors;

    if (requested_size_bytes) |req| {
        const req_sectors = (req + disk.SectorSize - 1) / disk.SectorSize;
        // Align up to 1 MiB boundary
        const aligned_sectors = ((req_sectors + disk.Alignment1MiB - 1) / disk.Alignment1MiB) * disk.Alignment1MiB;
        if (aligned_sectors < alloc_sectors) {
            alloc_sectors = aligned_sectors;
        }
    }

    const next_num = findAvailablePartitionNumber(d.partitions.items);
    const new_node = try formatPartitionNode(allocator, d.node, next_num);
    errdefer allocator.free(new_node);

    return ExpandPlan{
        .disk_node = d.node,
        .mount_point = mount_point,
        .new_part_num = next_num,
        .new_part_node = new_node,
        .start_sector = start_sector,
        .size_sectors = alloc_sectors,
        .size_bytes = alloc_sectors * disk.SectorSize,
        .is_aligned = (start_sector % disk.Alignment1MiB == 0),
    };
}
