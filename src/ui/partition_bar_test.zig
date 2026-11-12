//! OSCraft — Partition Bar Unit Tests
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const disk = @import("../storage/disk.zig");
const partition_bar = @import("partition_bar.zig");

test "partition_bar: formatSize formats bytes into readable units" {
    var buf: [32]u8 = undefined;

    const kib = partition_bar.formatSize(1024 * 512, &buf);
    try std.testing.expectEqualStrings("512 KiB", kib);

    const mib = partition_bar.formatSize(1024 * 1024 * 64, &buf);
    try std.testing.expectEqualStrings("64 MiB", mib);

    const gib = partition_bar.formatSize(1024 * 1024 * 1024 * 50, &buf);
    try std.testing.expectEqualStrings("50.0 GiB", gib);
}

test "partition_bar: buildSegments interleaves partitions and gaps topologically" {
    const allocator = std.testing.allocator;

    var test_disk = disk.Disk{
        .allocator = allocator,
        .name = "sda",
        .node = "/dev/sda",
        .model = "Test NVMe Drive",
        .size_sectors = 2000000,
        .size_bytes = 2000000 * 512,
        .partitions = .empty,
        .gaps = .empty,
    };
    defer test_disk.deinit();

    // Part 1: sectors 2048 .. 102399 (100352 sectors)
    try test_disk.partitions.append(allocator, .{
        .name = "sda1",
        .node = "/dev/sda1",
        .part_num = 1,
        .start_sector = 2048,
        .size_sectors = 100352,
        .size_bytes = 100352 * 512,
        .fstype = "vfat",
        .label = "EFI",
        .mountpoint = "/boot/efi",
    });

    // Part 2: sectors 500000 .. 1500000 (1000001 sectors)
    try test_disk.partitions.append(allocator, .{
        .name = "sda2",
        .node = "/dev/sda2",
        .part_num = 2,
        .start_sector = 500000,
        .size_sectors = 1000001,
        .size_bytes = 1000001 * 512,
        .fstype = "btrfs",
        .label = "root",
        .mountpoint = "/",
    });

    // Gap between p1 and p2: sectors 102400 .. 499999
    try test_disk.gaps.append(allocator, .{
        .start_sector = 102400,
        .end_sector = 499999,
        .size_sectors = 397600,
        .size_bytes = 397600 * 512,
        .is_aligned = true,
    });

    var segments_buf: [16]partition_bar.BarSegment = undefined;
    const count = partition_bar.buildSegments(&test_disk, &segments_buf);

    try std.testing.expectEqual(@as(usize, 3), count);

    // Segment 0 must be sda1
    try std.testing.expectEqual(partition_bar.SegmentKind.partition, segments_buf[0].kind);
    try std.testing.expectEqualStrings("sda1", segments_buf[0].getLabel());
    try std.testing.expectEqual(@as(u64, 2048), segments_buf[0].start_sector);

    // Segment 1 must be the unallocated gap
    try std.testing.expectEqual(partition_bar.SegmentKind.gap, segments_buf[1].kind);
    try std.testing.expectEqualStrings("FREE SPACE", segments_buf[1].getLabel());
    try std.testing.expectEqual(@as(u64, 102400), segments_buf[1].start_sector);

    // Segment 2 must be sda2
    try std.testing.expectEqual(partition_bar.SegmentKind.partition, segments_buf[2].kind);
    try std.testing.expectEqualStrings("sda2", segments_buf[2].getLabel());
    try std.testing.expectEqual(@as(u64, 500000), segments_buf[2].start_sector);
}
