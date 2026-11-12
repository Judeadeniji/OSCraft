//! OSCraft — Storage Engine: Live Disk Probing Tests
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const probe = @import("probe.zig");
const disk = @import("disk.zig");

test "unit: filter physical vs virtual block devices" {
    const testing = std.testing;

    try testing.expect(probe.isPhysicalDisk("sda"));
    try testing.expect(probe.isPhysicalDisk("sdb"));
    try testing.expect(probe.isPhysicalDisk("nvme0n1"));
    try testing.expect(probe.isPhysicalDisk("vda"));

    try testing.expect(!probe.isPhysicalDisk("loop0"));
    try testing.expect(!probe.isPhysicalDisk("ram0"));
    try testing.expect(!probe.isPhysicalDisk("zram0"));
    try testing.expect(!probe.isPhysicalDisk("dm-0"));
    try testing.expect(!probe.isPhysicalDisk("sr0"));
}

test "unit: parse sfdisk dump format and calculate real gaps" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const mock_sfdisk_dump =
        \\label: gpt
        \\label-id: 11111111-2222-3333-4444-555555555555
        \\device: /dev/sda
        \\unit: sectors
        \\first-lba: 34
        \\last-lba: 209715166
        \\sector-size: 512
        \\
        \\/dev/sda1 : start=        2048, size=     1048576, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
        \\/dev/sda2 : start=     1050624, size=    10485760, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
        \\/dev/sda3 : start=   100000000, size=    50000000, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
    ;

    var parsed_disk = try probe.parseSfdiskDump(allocator, mock_sfdisk_dump);
    defer probe.freeDisk(&parsed_disk);

    try testing.expectEqualStrings("/dev/sda", parsed_disk.name);
    try testing.expectEqual(@as(usize, 3), parsed_disk.partitions.items.len);

    try testing.expectEqual(@as(u64, 2048), parsed_disk.partitions.items[0].start_sector);
    try testing.expectEqual(@as(u64, 1048576), parsed_disk.partitions.items[0].size_sectors);

    // Calculate unallocated gaps from the parsed disk
    try parsed_disk.calculateGaps();
    const gaps = parsed_disk.gaps.items;

    // Gap between partition 2 and partition 3, and gap after partition 3 up to disk end
    try testing.expect(gaps.len >= 2);
    try testing.expect(gaps[0].start_sector > parsed_disk.partitions.items[1].endSector());
    try testing.expect(gaps[0].end_sector < parsed_disk.partitions.items[2].start_sector);
    try testing.expect(gaps[0].sizeGiB() > 40.0); // ~42 GiB gap
}
