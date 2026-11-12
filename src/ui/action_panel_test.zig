//! OSCraft — Diagnostics & Action Panel Unit Tests
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const disk = @import("../storage/disk.zig");
const action_panel = @import("action_panel.zig");

test "action_panel: ActionPlan detects largest gap and next partition number" {
    const allocator = std.testing.allocator;

    var test_disk = disk.Disk{
        .allocator = allocator,
        .name = "nvme0n1",
        .node = "/dev/nvme0n1",
        .model = "Samsung 980 PRO",
        .size_sectors = 10000000,
        .size_bytes = 10000000 * 512,
        .partitions = .empty,
        .gaps = .empty,
    };
    defer test_disk.deinit();

    try test_disk.partitions.append(allocator, .{
        .name = "nvme0n1p1",
        .node = "/dev/nvme0n1p1",
        .part_num = 1,
        .start_sector = 2048,
        .size_sectors = 102400,
        .size_bytes = 102400 * 512,
    });

    try test_disk.partitions.append(allocator, .{
        .name = "nvme0n1p2",
        .node = "/dev/nvme0n1p2",
        .part_num = 2,
        .start_sector = 200000,
        .size_sectors = 204800,
        .size_bytes = 204800 * 512,
    });

    // Small gap
    try test_disk.gaps.append(allocator, .{
        .start_sector = 104448,
        .end_sector = 199999,
        .size_sectors = 95552,
        .size_bytes = 95552 * 512,
        .is_aligned = true,
    });

    // Large gap
    try test_disk.gaps.append(allocator, .{
        .start_sector = 404800,
        .end_sector = 9999999,
        .size_sectors = 9595200,
        .size_bytes = 9595200 * 512,
        .is_aligned = true,
    });

    const plan = action_panel.ActionPlan.init(&test_disk);

    try std.testing.expect(plan.has_gap);
    try std.testing.expectEqual(@as(u32, 3), plan.next_part_num);
    try std.testing.expectEqual(@as(u64, 404800), plan.largest_gap_start);
    try std.testing.expectEqual(@as(u64, 9999999), plan.largest_gap_end);
    try std.testing.expectEqual(@as(u64, 9595200 * 512), plan.gap_bytes);
}

test "action_panel: ActionPlan with fully allocated disk" {
    const allocator = std.testing.allocator;

    var test_disk = disk.Disk{
        .allocator = allocator,
        .name = "sda",
        .node = "/dev/sda",
        .model = "Crucial SSD",
        .size_sectors = 2000000,
        .size_bytes = 2000000 * 512,
        .partitions = .empty,
        .gaps = .empty,
    };
    defer test_disk.deinit();

    try test_disk.partitions.append(allocator, .{
        .name = "sda1",
        .node = "/dev/sda1",
        .part_num = 1,
        .start_sector = 2048,
        .size_sectors = 1997952,
        .size_bytes = 1997952 * 512,
    });

    const plan = action_panel.ActionPlan.init(&test_disk);

    try std.testing.expect(!plan.has_gap);
    try std.testing.expectEqual(@as(u32, 2), plan.next_part_num);
    try std.testing.expectEqual(@as(u64, 0), plan.gap_bytes);
}
