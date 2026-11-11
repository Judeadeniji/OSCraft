//! OSCraft — Storage Engine: Disk Topology & Gap Analysis
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

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
