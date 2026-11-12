//! OSCraft — Storage Engine: Btrfs Companion Tests
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const btrfs = @import("btrfs.zig");

test "flow: parse human readable size formats" {
    const testing = std.testing;

    // GiB
    const gib = btrfs.parseHumanSize("100.00GiB");
    try testing.expect(gib != null);
    try testing.expectEqual(@as(u64, 100 * 1024 * 1024 * 1024), gib.?);

    // MiB
    const mib = btrfs.parseHumanSize("512MiB");
    try testing.expect(mib != null);
    try testing.expectEqual(@as(u64, 512 * 1024 * 1024), mib.?);

    // KiB
    const kib = btrfs.parseHumanSize("16.00KiB");
    try testing.expect(kib != null);
    try testing.expectEqual(@as(u64, 16 * 1024), kib.?);

    // Bytes
    const b = btrfs.parseHumanSize("4096B");
    try testing.expect(b != null);
    try testing.expectEqual(@as(u64, 4096), b.?);

    // Invalid unit
    const inv = btrfs.parseHumanSize("100Foo");
    try testing.expect(inv == null);
}

test "flow: build safe btrfs device add command" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const args = try btrfs.buildDeviceAddArgs(allocator, "/dev/nvme0n1p3", "/", true);
    defer allocator.free(args);

    try testing.expectEqual(@as(usize, 6), args.len);
    try testing.expectEqualStrings("btrfs", args[0]);
    try testing.expectEqualStrings("device", args[1]);
    try testing.expectEqualStrings("add", args[2]);
    try testing.expectEqualStrings("-f", args[3]);
    try testing.expectEqualStrings("/dev/nvme0n1p3", args[4]);
    try testing.expectEqualStrings("/", args[5]);
}

test "flow: build safe btrfs device remove command" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const args = try btrfs.buildDeviceRemoveArgs(allocator, "/dev/nvme0n1p3", "/");
    defer allocator.free(args);

    try testing.expectEqual(@as(usize, 5), args.len);
    try testing.expectEqualStrings("btrfs", args[0]);
    try testing.expectEqualStrings("device", args[1]);
    try testing.expectEqualStrings("remove", args[2]);
    try testing.expectEqualStrings("/dev/nvme0n1p3", args[3]);
    try testing.expectEqualStrings("/", args[4]);
}

test "flow: multi-device filesystem containment and total capacity" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var fs = btrfs.BtrfsFilesystem{
        .allocator = allocator,
        .label = "os-root",
        .uuid = "00000000-1111-2222-3333-444444444444",
        .total_devices = 2,
        .devices = .empty,
    };
    defer fs.deinit();

    // Primary device: 100 GB
    try fs.devices.append(allocator, .{
        .devid = 1,
        .path = "/dev/nvme0n1p2",
        .size_bytes = 100 * 1024 * 1024 * 1024,
        .used_bytes = 40 * 1024 * 1024 * 1024,
    });

    // Secondary device: 50 GB
    try fs.devices.append(allocator, .{
        .devid = 2,
        .path = "/dev/nvme0n1p3",
        .size_bytes = 50 * 1024 * 1024 * 1024,
        .used_bytes = 10 * 1024 * 1024 * 1024,
    });

    // Containment verification
    try testing.expect(fs.containsDevice("/dev/nvme0n1p2"));
    try testing.expect(fs.containsDevice("/dev/nvme0n1p3"));
    try testing.expect(!fs.containsDevice("/dev/nvme0n1p4"));

    // Total capacity: 150 GB
    try testing.expectEqual(@as(u64, 150 * 1024 * 1024 * 1024), fs.totalSizeBytes());

    // Total used: 50 GB
    try testing.expectEqual(@as(u64, 50 * 1024 * 1024 * 1024), fs.totalUsedBytes());
}

test "flow: allocation mode parsing" {
    const testing = std.testing;

    try testing.expectEqual(btrfs.AllocationMode.single, btrfs.AllocationMode.parse("single"));
    try testing.expectEqual(btrfs.AllocationMode.dup, btrfs.AllocationMode.parse("DUP"));
    try testing.expectEqual(btrfs.AllocationMode.raid1, btrfs.AllocationMode.parse("RAID1"));
    try testing.expectEqual(btrfs.AllocationMode.unknown, btrfs.AllocationMode.parse("custom_unsupported"));
}
