const std = @import("std");

pub const SectorSize = 512;
pub const Alignment1MiB = (1024 * 1024) / SectorSize; // 2048 sectors
pub const GptHeaderSectors = 34; // 1 sector MBR/header + 32 partition entry sectors + 1 GPT header
pub const FirstUsableSector = 2048; // Standard 1 MiB offset for first partition

pub const DiskGap = struct {
    start_sector: u64,
    end_sector: u64,
    size_sectors: u64,
    size_bytes: u64,
    is_aligned: bool,

    pub fn sizeGiB(self: DiskGap) f64 {
        return @as(f64, @floatFromInt(self.size_bytes)) / (1024.0 * 1024.0 * 1024.0);
    }
};

pub const Partition = struct {
    name: []const u8,
    node: []const u8,
    part_num: u32,
    start_sector: u64,
    size_sectors: u64,
    size_bytes: u64,
    fstype: ?[]const u8 = null,
    label: ?[]const u8 = null,
    mountpoint: ?[]const u8 = null,

    pub fn endSector(self: Partition) u64 {
        if (self.size_sectors == 0) return self.start_sector;
        return self.start_sector + self.size_sectors - 1;
    }

    pub fn sizeGiB(self: Partition) f64 {
        return @as(f64, @floatFromInt(self.size_bytes)) / (1024.0 * 1024.0 * 1024.0);
    }
};

pub const PartitionPlan = struct {
    start_sector: u64,
    end_sector: u64,
    size_sectors: u64,
    size_bytes: u64,
    remaining_gap: ?DiskGap,
};

pub const Disk = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    node: []const u8,
    model: []const u8,
    size_sectors: u64,
    size_bytes: u64,
    partitions: std.ArrayListUnmanaged(Partition),
    gaps: std.ArrayListUnmanaged(DiskGap),

    pub fn deinit(self: *Disk) void {
        self.partitions.deinit(self.allocator);
        self.gaps.deinit(self.allocator);
    }

    pub fn totalGiB(self: Disk) f64 {
        return @as(f64, @floatFromInt(self.size_bytes)) / (1024.0 * 1024.0 * 1024.0);
    }

    /// Sorts partitions topologically by physical start_sector and discovers all unallocated gaps.
    pub fn calculateGaps(self: *Disk) !void {
        self.gaps.clearRetainingCapacity();

        const parts = self.partitions.items;
        if (parts.len == 0) {
            // Whole disk is unallocated between primary and backup GPT headers
            if (self.size_sectors > FirstUsableSector + GptHeaderSectors) {
                const start = FirstUsableSector;
                const end = self.size_sectors - GptHeaderSectors;
                const count = end - start + 1;
                try self.gaps.append(self.allocator, .{
                    .start_sector = start,
                    .end_sector = end,
                    .size_sectors = count,
                    .size_bytes = count * SectorSize,
                    .is_aligned = (start % Alignment1MiB == 0),
                });
            }
            return;
        }

        // Sort partitions by start_sector so table order doesn't affect physical topology
        std.mem.sort(Partition, parts, {}, struct {
            fn lessThan(_: void, a: Partition, b: Partition) bool {
                return a.start_sector < b.start_sector;
            }
        }.lessThan);

        // Gap before first partition (from 2048 to first partition start)
        if (parts[0].start_sector > FirstUsableSector) {
            const gap_start = FirstUsableSector;
            const gap_end = parts[0].start_sector - 1;
            const count = gap_end - gap_start + 1;
            if (count >= Alignment1MiB) {
                try self.gaps.append(self.allocator, .{
                    .start_sector = gap_start,
                    .end_sector = gap_end,
                    .size_sectors = count,
                    .size_bytes = count * SectorSize,
                    .is_aligned = (gap_start % Alignment1MiB == 0),
                });
            }
        }

        // Gaps between consecutive partitions
        var i: usize = 0;
        while (i + 1 < parts.len) : (i += 1) {
            const current_end = parts[i].endSector();
            const next_start = parts[i + 1].start_sector;
            if (next_start > current_end + 1) {
                const gap_start = current_end + 1;
                const gap_end = next_start - 1;
                const count = gap_end - gap_start + 1;
                // Only register gaps that are at least 1 MiB
                if (count >= Alignment1MiB) {
                    try self.gaps.append(self.allocator, .{
                        .start_sector = gap_start,
                        .end_sector = gap_end,
                        .size_sectors = count,
                        .size_bytes = count * SectorSize,
                        .is_aligned = (gap_start % Alignment1MiB == 0),
                    });
                }
            }
        }

        // Gap after last partition (before backup GPT header at disk end - GptHeaderSectors)
        if (self.size_sectors > GptHeaderSectors) {
            const last_usable = self.size_sectors - GptHeaderSectors;
            const last_end = parts[parts.len - 1].endSector();
            if (last_usable > last_end) {
                const gap_start = last_end + 1;
                const gap_end = last_usable;
                const count = gap_end - gap_start + 1;
                if (count >= Alignment1MiB) {
                    try self.gaps.append(self.allocator, .{
                        .start_sector = gap_start,
                        .end_sector = gap_end,
                        .size_sectors = count,
                        .size_bytes = count * SectorSize,
                        .is_aligned = (gap_start % Alignment1MiB == 0),
                    });
                }
            }
        }
    }

    /// Finds the first unallocated gap that can satisfy `requested_bytes`.
    pub fn findUsableGap(self: Disk, requested_bytes: u64) ?DiskGap {
        for (self.gaps.items) |gap| {
            if (gap.size_bytes >= requested_bytes) {
                return gap;
            }
        }
        return null;
    }

    /// Slices an existing gap to produce a 1 MiB sector-aligned partition plan.
    pub fn planPartition(gap: DiskGap, requested_bytes: u64) !PartitionPlan {
        if (requested_bytes == 0) return error.ZeroSizeRequested;
        if (gap.size_bytes < requested_bytes) return error.InsufficientSpace;

        // Calculate needed sectors, rounding up to 1 MiB alignment
        var needed_sectors = (requested_bytes + SectorSize - 1) / SectorSize;
        if (needed_sectors % Alignment1MiB != 0) {
            needed_sectors += (Alignment1MiB - (needed_sectors % Alignment1MiB));
        }

        if (needed_sectors > gap.size_sectors) {
            return error.InsufficientSpace;
        }

        // Ensure start sector is 1 MiB aligned
        var aligned_start = gap.start_sector;
        if (aligned_start % Alignment1MiB != 0) {
            aligned_start += (Alignment1MiB - (aligned_start % Alignment1MiB));
        }

        const plan_end = aligned_start + needed_sectors - 1;
        if (plan_end > gap.end_sector) {
            return error.InsufficientSpace;
        }

        const plan_bytes = needed_sectors * SectorSize;

        // Check if there is remaining space in the gap after slicing
        var remaining: ?DiskGap = null;
        if (plan_end < gap.end_sector) {
            const rem_start = plan_end + 1;
            const rem_end = gap.end_sector;
            const rem_count = rem_end - rem_start + 1;
            if (rem_count >= Alignment1MiB) {
                remaining = .{
                    .start_sector = rem_start,
                    .end_sector = rem_end,
                    .size_sectors = rem_count,
                    .size_bytes = rem_count * SectorSize,
                    .is_aligned = (rem_start % Alignment1MiB == 0),
                };
            }
        }

        return PartitionPlan{
            .start_sector = aligned_start,
            .end_sector = plan_end,
            .size_sectors = needed_sectors,
            .size_bytes = plan_bytes,
            .remaining_gap = remaining,
        };
    }
};

/// Reads an integer from a sysfs file, e.g. /sys/block/sda/size
pub fn readSysfsU64(path: []const u8) !u64 {
    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    var buf: [64]u8 = undefined;
    const len = try file.readAll(&buf);
    const trimmed = std.mem.trim(u8, buf[0..len], " \t\r\n");
    return std.fmt.parseInt(u64, trimmed, 10);
}

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
    try testing.expectEqual(@as(u64, 2048), gap.start_sector);
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
