//! OSCraft — Storage Engine: Live Partition Allocation Tests
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const expand = @import("expand.zig");
const disk = @import("disk.zig");

test "unit: find available partition numbers including holes" {
    const testing = std.testing;

    const parts_seq = [_]disk.Partition{
        .{ .name = "sda1", .node = "/dev/sda1", .part_num = 1, .start_sector = 2048, .size_sectors = 1000, .size_bytes = 512000 },
        .{ .name = "sda2", .node = "/dev/sda2", .part_num = 2, .start_sector = 4096, .size_sectors = 1000, .size_bytes = 512000 },
    };
    try testing.expectEqual(@as(u32, 3), expand.findAvailablePartitionNumber(&parts_seq));

    // Non-sequential: 1, 2, 4, 5 -> should find hole 3
    const parts_hole = [_]disk.Partition{
        .{ .name = "sda1", .node = "/dev/sda1", .part_num = 1, .start_sector = 2048, .size_sectors = 1000, .size_bytes = 512000 },
        .{ .name = "sda2", .node = "/dev/sda2", .part_num = 2, .start_sector = 4096, .size_sectors = 1000, .size_bytes = 512000 },
        .{ .name = "sda4", .node = "/dev/sda4", .part_num = 4, .start_sector = 8192, .size_sectors = 1000, .size_bytes = 512000 },
        .{ .name = "sda5", .node = "/dev/sda5", .part_num = 5, .start_sector = 10240, .size_sectors = 1000, .size_bytes = 512000 },
    };
    try testing.expectEqual(@as(u32, 3), expand.findAvailablePartitionNumber(&parts_hole));
}

test "unit: format partition nodes for standard and NVMe block devices" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const sda_node = try expand.formatPartitionNode(allocator, "/dev/sda", 3);
    defer allocator.free(sda_node);
    try testing.expectEqualStrings("/dev/sda3", sda_node);

    const nvme_node = try expand.formatPartitionNode(allocator, "/dev/nvme0n1", 2);
    defer allocator.free(nvme_node);
    try testing.expectEqualStrings("/dev/nvme0n1p2", nvme_node);
}

test "unit: plan live btrfs expansion and verify sgdisk and btrfs arguments" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var test_disk = disk.Disk{
        .allocator = allocator,
        .name = "/dev/sda",
        .node = "/dev/sda",
        .model = "Test Drive",
        .size_sectors = 976773168,
        .size_bytes = 976773168 * 512,
        .partitions = .empty,
        .gaps = .empty,
    };
    defer test_disk.deinit();

    // Add a 200 GiB unallocated gap starting at sector 2048000 (1 MiB aligned)
    try test_disk.gaps.append(allocator, .{
        .start_sector = 2048000,
        .end_sector = 421888000,
        .size_sectors = 419840000,
        .size_bytes = 419840000 * 512,
        .is_aligned = true,
    });

    // Request 50 GiB allocation
    const req_bytes: u64 = 50 * 1024 * 1024 * 1024;
    const plan = try expand.planLiveBtrfsExpansion(allocator, test_disk, "/", req_bytes);
    defer allocator.free(plan.new_part_node);

    try testing.expectEqualStrings("/dev/sda", plan.disk_node);
    try testing.expectEqualStrings("/", plan.mount_point);
    try testing.expectEqualStrings("/dev/sda1", plan.new_part_node);
    try testing.expect(plan.is_aligned);
    try testing.expect(plan.sizeGiB() >= 50.0);

    // Verify sgdisk command construction
    const sgdisk_args = try plan.buildPartitionCreateArgs(allocator);
    defer {
        allocator.free(sgdisk_args[1]);
        allocator.free(sgdisk_args[2]);
        allocator.free(sgdisk_args);
    }

    try testing.expectEqual(@as(usize, 4), sgdisk_args.len);
    try testing.expectEqualStrings("sgdisk", sgdisk_args[0]);
    try testing.expectEqualStrings("/dev/sda", sgdisk_args[3]);

    // Verify btrfs device add command construction
    const btrfs_args = try plan.buildBtrfsAddArgs(allocator);
    defer allocator.free(btrfs_args);

    try testing.expectEqual(@as(usize, 6), btrfs_args.len);
    try testing.expectEqualStrings("btrfs", btrfs_args[0]);
    try testing.expectEqualStrings("device", btrfs_args[1]);
    try testing.expectEqualStrings("add", btrfs_args[2]);
    try testing.expectEqualStrings("-f", btrfs_args[3]);
    try testing.expectEqualStrings("/dev/sda1", btrfs_args[4]);
    try testing.expectEqualStrings("/", btrfs_args[5]);
}
