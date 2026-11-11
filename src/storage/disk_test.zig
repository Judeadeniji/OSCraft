const std = @import("std");
const disk_mod = @import("disk.zig");

const Disk = disk_mod.Disk;
const DiskGap = disk_mod.DiskGap;
const Partition = disk_mod.Partition;
const PartitionPlan = disk_mod.PartitionPlan;
const SectorSize = disk_mod.SectorSize;
const Alignment1MiB = disk_mod.Alignment1MiB;
const GptHeaderSectors = disk_mod.GptHeaderSectors;
const FirstUsableSector = disk_mod.FirstUsableSector;

// ============================================================================
// Comprehensive Behavioral & Flow Test Suite
// ============================================================================

test "flow: completely empty disk creates single full-range gap" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var disk = Disk{
        .allocator = allocator,
        .name = "sda",
        .node = "/dev/sda",
        .model = "Raw NVMe",
        .size_sectors = 1_000_000,
        .size_bytes = 1_000_000 * SectorSize,
        .partitions = .empty,
        .gaps = .empty,
    };
    defer disk.deinit();

    try disk.calculateGaps();

    try testing.expectEqual(@as(usize, 1), disk.gaps.items.len);
    const gap = disk.gaps.items[0];
    try testing.expectEqual(@as(u64, FirstUsableSector), gap.start_sector);
    try testing.expectEqual(@as(u64, 1_000_000 - GptHeaderSectors), gap.end_sector);
    try testing.expect(gap.is_aligned);
}

test "flow: real-world multi-boot disk with deleted partition (Bliss OS scenario)" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Mimic the exact 500GB drive (/dev/sda) from our actual system:
    // Total sectors: 976,773,168 sectors (~500.1 GB)
    var disk = Disk{
        .allocator = allocator,
        .name = "sda",
        .node = "/dev/sda",
        .model = "Samsung SSD",
        .size_sectors = 976_773_168,
        .size_bytes = 976_773_168 * SectorSize,
        .partitions = .empty,
        .gaps = .empty,
    };
    defer disk.deinit();

    // sda1: ESP (100 MB)
    try disk.partitions.append(allocator, .{
        .name = "sda1",
        .node = "/dev/sda1",
        .part_num = 1,
        .start_sector = 2048,
        .size_sectors = 204800,
        .size_bytes = 204800 * SectorSize,
    });

    // sda2: MSR (16 MB)
    try disk.partitions.append(allocator, .{
        .name = "sda2",
        .node = "/dev/sda2",
        .part_num = 2,
        .start_sector = 206848,
        .size_sectors = 32768,
        .size_bytes = 32768 * SectorSize,
    });

    // sda4: OEM Recovery (1 GB)
    try disk.partitions.append(allocator, .{
        .name = "sda4",
        .node = "/dev/sda4",
        .part_num = 4,
        .start_sector = 239616,
        .size_sectors = 2097152,
        .size_bytes = 2097152 * SectorSize,
    });

    // sda5: Btrfs Root (starts at sector 687,720,448, size ~137.8 GB)
    try disk.partitions.append(allocator, .{
        .name = "sda5",
        .node = "/dev/sda5",
        .part_num = 5,
        .start_sector = 687720448,
        .size_sectors = 289052687,
        .size_bytes = 289052687 * SectorSize,
    });

    try disk.calculateGaps();

    // Verify: exactly 1 significant gap exists (between sda4 and sda5)
    try testing.expectEqual(@as(usize, 1), disk.gaps.items.len);

    const gap = disk.gaps.items[0];
    // Must start right after sda4 ends: 239616 + 2097152 = 2336768
    try testing.expectEqual(@as(u64, 2336768), gap.start_sector);
    // Must end right before sda5 begins: 687720448 - 1 = 687720447
    try testing.expectEqual(@as(u64, 687720447), gap.end_sector);
    // Size check: 687720448 - 2336768 = 685383680 sectors (~326.8 GiB)
    try testing.expectEqual(@as(u64, 685383680), gap.size_sectors);
    try testing.expect(gap.is_aligned);
    try testing.expect(gap.sizeGiB() > 326.0 and gap.sizeGiB() < 327.0);
}

test "flow: partitions added out of order are topologically sorted" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var disk = Disk{
        .allocator = allocator,
        .name = "sda",
        .node = "/dev/sda",
        .model = "Test Out Of Order",
        .size_sectors = 20_000_000,
        .size_bytes = 20_000_000 * SectorSize,
        .partitions = .empty,
        .gaps = .empty,
    };
    defer disk.deinit();

    // Add partition 5 first!
    try disk.partitions.append(allocator, .{
        .name = "sda5",
        .node = "/dev/sda5",
        .part_num = 5,
        .start_sector = 10_000_000,
        .size_sectors = 2_000_000,
        .size_bytes = 2_000_000 * SectorSize,
    });

    // Add partition 1 second!
    try disk.partitions.append(allocator, .{
        .name = "sda1",
        .node = "/dev/sda1",
        .part_num = 1,
        .start_sector = 2048,
        .size_sectors = 204800,
        .size_bytes = 204800 * SectorSize,
    });

    try disk.calculateGaps();

    // Partitions should be sorted: sda1 (2048..206847), then gap, then sda5 (10_000_000..), then end gap
    try testing.expectEqual(@as(u64, 2048), disk.partitions.items[0].start_sector);
    try testing.expectEqual(@as(u64, 10_000_000), disk.partitions.items[1].start_sector);

    // Gap between sda1 and sda5
    const middle_gap = disk.gaps.items[0];
    try testing.expectEqual(@as(u64, 206848), middle_gap.start_sector);
    try testing.expectEqual(@as(u64, 9_999_999), middle_gap.end_sector);
}

test "flow: contiguous partitions produce zero gaps" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var disk = Disk{
        .allocator = allocator,
        .name = "sda",
        .node = "/dev/sda",
        .model = "Packed Disk",
        .size_sectors = 4096 + GptHeaderSectors,
        .size_bytes = (4096 + GptHeaderSectors) * SectorSize,
        .partitions = .empty,
        .gaps = .empty,
    };
    defer disk.deinit();

    // Part 1: exactly 2048 to 3071
    try disk.partitions.append(allocator, .{
        .name = "sda1",
        .node = "/dev/sda1",
        .part_num = 1,
        .start_sector = 2048,
        .size_sectors = 1024,
        .size_bytes = 1024 * SectorSize,
    });

    // Part 2: exactly 3072 to 4095 (no gap between 3071 and 3072!)
    try disk.partitions.append(allocator, .{
        .name = "sda2",
        .node = "/dev/sda2",
        .part_num = 2,
        .start_sector = 3072,
        .size_sectors = 1024,
        .size_bytes = 1024 * SectorSize,
    });

    try disk.calculateGaps();

    // No gaps inside or outside!
    try testing.expectEqual(@as(usize, 0), disk.gaps.items.len);
}

test "flow: sub-1MiB residual gaps are ignored" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var disk = Disk{
        .allocator = allocator,
        .name = "sda",
        .node = "/dev/sda",
        .model = "Misaligned Disk",
        .size_sectors = 10_000,
        .size_bytes = 10_000 * SectorSize,
        .partitions = .empty,
        .gaps = .empty,
    };
    defer disk.deinit();

    // Part 1: 2048 to 3071
    try disk.partitions.append(allocator, .{
        .name = "sda1",
        .node = "/dev/sda1",
        .part_num = 1,
        .start_sector = 2048,
        .size_sectors = 1024,
        .size_bytes = 1024 * SectorSize,
    });

    // Part 2: 3572 to 5000 (leaves 3072..3571 = 500 sectors, which is < Alignment1MiB / 2048 sectors)
    try disk.partitions.append(allocator, .{
        .name = "sda2",
        .node = "/dev/sda2",
        .part_num = 2,
        .start_sector = 3572,
        .size_sectors = 1429,
        .size_bytes = 1429 * SectorSize,
    });

    try disk.calculateGaps();

    // The 500 sector gap must NOT be reported as a usable gap
    for (disk.gaps.items) |gap| {
        try testing.expect(gap.start_sector != 3072);
    }
}

test "flow: partition allocation plan enforces 1 MiB alignment and handles remainder" {
    const testing = std.testing;

    // A gap from sector 2336768 to 687720447 (~326 GiB)
    const gap = DiskGap{
        .start_sector = 2336768,
        .end_sector = 687720447,
        .size_sectors = 687720447 - 2336768 + 1,
        .size_bytes = (687720447 - 2336768 + 1) * SectorSize,
        .is_aligned = true,
    };

    // User requests: 100 GiB (100 * 1024 * 1024 * 1024 bytes)
    const requested_bytes: u64 = 100 * 1024 * 1024 * 1024;
    const plan = try Disk.planPartition(gap, requested_bytes);

    // Verify start is 2336768 (1 MiB aligned)
    try testing.expectEqual(@as(u64, 2336768), plan.start_sector);
    try testing.expectEqual(@as(u64, 0), plan.start_sector % Alignment1MiB);

    // 100 GiB in 512-byte sectors: 209,715,200 sectors
    const expected_sectors: u64 = 209715200;
    try testing.expectEqual(expected_sectors, plan.size_sectors);
    try testing.expectEqual(plan.start_sector + expected_sectors - 1, plan.end_sector);

    // Verify end sector: 2336768 + 209715200 - 1 = 212051967
    try testing.expectEqual(@as(u64, 212051967), plan.end_sector);

    // Verify remainder: must start at 212051968 and end at 687720447
    try testing.expect(plan.remaining_gap != null);
    const rem = plan.remaining_gap.?;
    try testing.expectEqual(@as(u64, 212051968), rem.start_sector);
    try testing.expectEqual(@as(u64, 687720447), rem.end_sector);
    try testing.expect(rem.is_aligned);
    try testing.expectEqual(@as(u64, 0), rem.start_sector % Alignment1MiB);
}

test "flow: allocation fails cleanly when requested size exceeds gap" {
    const testing = std.testing;

    const gap = DiskGap{
        .start_sector = 2048,
        .end_sector = 4095, // only 2048 sectors (1 MiB)
        .size_sectors = 2048,
        .size_bytes = 2048 * SectorSize,
        .is_aligned = true,
    };

    // Requesting 10 MiB when only 1 MiB is available
    const err = Disk.planPartition(gap, 10 * 1024 * 1024);
    try testing.expectError(error.InsufficientSpace, err);
}

test "flow: allocation fails cleanly on zero size request" {
    const testing = std.testing;

    const gap = DiskGap{
        .start_sector = 2048,
        .end_sector = 4095,
        .size_sectors = 2048,
        .size_bytes = 2048 * SectorSize,
        .is_aligned = true,
    };

    const err = Disk.planPartition(gap, 0);
    try testing.expectError(error.ZeroSizeRequested, err);
}
