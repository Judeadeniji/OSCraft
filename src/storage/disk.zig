const std = @import("std");

pub const SectorSize: u64 = 512;
pub const Alignment1MiB: u64 = 2048; // 1 MiB / 512 bytes = 2048 sectors

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

    /// Sorts partitions and computes unallocated gaps between them.
    pub fn calculateGaps(self: *Disk) !void {
        self.gaps.clearRetainingCapacity();

        const parts = self.partitions.items;
        if (parts.len == 0) {
            // Whole disk is unallocated (accounting for GPT headers, standard start 2048)
            if (self.size_sectors > 2048 + 34) {
                const start = 2048;
                const end = self.size_sectors - 34;
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

        // Sort partitions by start_sector
        std.mem.sort(Partition, parts, {}, struct {
            fn lessThan(_: void, a: Partition, b: Partition) bool {
                return a.start_sector < b.start_sector;
            }
        }.lessThan);

        // Gap before first partition (GPT reserve starts at 2048)
        const first_usable: u64 = 2048;
        if (parts[0].start_sector > first_usable) {
            const gap_start = first_usable;
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

        // Gap after last partition (before backup GPT header at disk end - 34)
        if (self.size_sectors > 34) {
            const last_usable = self.size_sectors - 34;
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

test "disk gap calculation with mock partitions" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var disk = Disk{
        .allocator = allocator,
        .name = "sda",
        .node = "/dev/sda",
        .model = "Test SSD",
        .size_sectors = 10000000,
        .size_bytes = 10000000 * SectorSize,
        .partitions = .empty,
        .gaps = .empty,
    };
    defer disk.deinit();

    // Add partition 1: 2048 to 206847 (100MB)
    try disk.partitions.append(allocator, .{
        .name = "sda1",
        .node = "/dev/sda1",
        .part_num = 1,
        .start_sector = 2048,
        .size_sectors = 204800,
        .size_bytes = 204800 * SectorSize,
    });

    // Add partition 2: with a 2,000,000 sector gap before it!
    // Start at 2206848, size 2048000
    try disk.partitions.append(allocator, .{
        .name = "sda2",
        .node = "/dev/sda2",
        .part_num = 2,
        .start_sector = 2206848,
        .size_sectors = 2048000,
        .size_bytes = 2048000 * SectorSize,
    });

    try disk.calculateGaps();

    // We should detect the gap between sda1 and sda2, and after sda2!
    try testing.expectEqual(@as(usize, 2), disk.gaps.items.len);

    const gap1 = disk.gaps.items[0];
    try testing.expectEqual(@as(u64, 206848), gap1.start_sector);
    try testing.expectEqual(@as(u64, 2206847), gap1.end_sector);
    try testing.expect(gap1.is_aligned);
}
