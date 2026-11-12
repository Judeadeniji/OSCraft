//! OSCraft — Storage Engine: Btrfs Live Pooling & Inspection
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");

pub const BtrfsDevice = struct {
    devid: u32,
    path: []const u8,
    size_bytes: u64,
    used_bytes: u64,
    is_missing: bool = false,
};

pub const AllocationMode = enum {
    single,
    dup,
    raid0,
    raid1,
    raid5,
    raid6,
    raid10,
    unknown,

    pub fn parse(str: []const u8) AllocationMode {
        if (std.mem.eql(u8, str, "single")) return .single;
        if (std.mem.eql(u8, str, "DUP")) return .dup;
        if (std.mem.eql(u8, str, "dup")) return .dup;
        if (std.mem.eql(u8, str, "RAID0")) return .raid0;
        if (std.mem.eql(u8, str, "RAID1")) return .raid1;
        if (std.mem.eql(u8, str, "RAID5")) return .raid5;
        if (std.mem.eql(u8, str, "RAID6")) return .raid6;
        if (std.mem.eql(u8, str, "RAID10")) return .raid10;
        return .unknown;
    }
};

pub const ProfileUsage = struct {
    mode: AllocationMode,
    total_bytes: u64,
    used_bytes: u64,
};

pub const FilesystemProfiles = struct {
    data: ?ProfileUsage = null,
    metadata: ?ProfileUsage = null,
    system: ?ProfileUsage = null,
    global_reserve: ?ProfileUsage = null,
};

pub const BtrfsFilesystem = struct {
    allocator: std.mem.Allocator,
    label: ?[]const u8,
    uuid: []const u8,
    total_devices: u32,
    devices: std.ArrayListUnmanaged(BtrfsDevice),

    pub fn deinit(self: *BtrfsFilesystem) void {
        self.devices.deinit(self.allocator);
    }

    /// Checks if a given device node (e.g. "/dev/nvme0n1p3") is already part of this filesystem.
    pub fn containsDevice(self: BtrfsFilesystem, path: []const u8) bool {
        for (self.devices.items) |dev| {
            if (std.mem.eql(u8, dev.path, path)) {
                return true;
            }
        }
        return false;
    }

    /// Total capacity summed across all member devices.
    pub fn totalSizeBytes(self: BtrfsFilesystem) u64 {
        var total: u64 = 0;
        for (self.devices.items) |dev| {
            total += dev.size_bytes;
        }
        return total;
    }

    /// Total space currently used across all member devices.
    pub fn totalUsedBytes(self: BtrfsFilesystem) u64 {
        var total: u64 = 0;
        for (self.devices.items) |dev| {
            total += dev.used_bytes;
        }
        return total;
    }
};

/// Builds the argument list for a live `btrfs device add` command.
pub fn buildDeviceAddArgs(
    allocator: std.mem.Allocator,
    target_device: []const u8,
    mountpoint: []const u8,
    force: bool,
) ![]const []const u8 {
    if (force) {
        return allocator.dupe([]const u8, &.{
            "btrfs", "device", "add", "-f", target_device, mountpoint,
        });
    } else {
        return allocator.dupe([]const u8, &.{
            "btrfs", "device", "add", target_device, mountpoint,
        });
    }
}

/// Builds the argument list for a live `btrfs device remove` command.
pub fn buildDeviceRemoveArgs(
    allocator: std.mem.Allocator,
    target_device: []const u8,
    mountpoint: []const u8,
) ![]const []const u8 {
    return allocator.dupe([]const u8, &.{
        "btrfs", "device", "remove", target_device, mountpoint,
    });
}

/// Helper to parse human-readable sizes (e.g., "117.81GiB", "80.25MiB", "16.00KiB", "0.00B") into bytes.
pub fn parseHumanSize(str: []const u8) ?u64 {
    const trimmed = std.mem.trim(u8, str, " \t\r\n");
    if (trimmed.len == 0) return null;

    var num_len: usize = 0;
    while (num_len < trimmed.len and (std.ascii.isDigit(trimmed[num_len]) or trimmed[num_len] == '.')) : (num_len += 1) {}

    const num_str = trimmed[0..num_len];
    const unit_str = trimmed[num_len..];

    const val = std.fmt.parseFloat(f64, num_str) catch return null;

    var multiplier: f64 = 1.0;
    if (std.mem.eql(u8, unit_str, "B") or unit_str.len == 0) {
        multiplier = 1.0;
    } else if (std.mem.eql(u8, unit_str, "KiB") or std.mem.eql(u8, unit_str, "K")) {
        multiplier = 1024.0;
    } else if (std.mem.eql(u8, unit_str, "MiB") or std.mem.eql(u8, unit_str, "M")) {
        multiplier = 1024.0 * 1024.0;
    } else if (std.mem.eql(u8, unit_str, "GiB") or std.mem.eql(u8, unit_str, "G")) {
        multiplier = 1024.0 * 1024.0 * 1024.0;
    } else if (std.mem.eql(u8, unit_str, "TiB") or std.mem.eql(u8, unit_str, "T")) {
        multiplier = 1024.0 * 1024.0 * 1024.0 * 1024.0;
    } else {
        return null;
    }

    return @as(u64, @intFromFloat(val * multiplier));
}
