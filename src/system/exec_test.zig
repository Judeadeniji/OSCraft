//! OSCraft — System Execution Tests
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const exec = @import("exec.zig");

test "unit: dry run executor records partition and storage commands" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var executor = exec.SystemExecutor.init(allocator, testing.io, .dry_run);
    defer executor.deinit();

    // 1. Reload kernel partition table
    try executor.reloadPartitionTable("/dev/sda");
    try testing.expectEqual(@as(usize, 1), executor.history.items.len);
    try testing.expectEqualStrings("partprobe", executor.history.items[0].args[0]);
    try testing.expectEqualStrings("/dev/sda", executor.history.items[0].args[1]);

    // 2. Add Btrfs device
    try executor.addBtrfsDevice("/dev/sda3", "/");
    try testing.expectEqual(@as(usize, 2), executor.history.items.len);
    try testing.expectEqualStrings("btrfs", executor.history.items[1].args[0]);
    try testing.expectEqualStrings("device", executor.history.items[1].args[1]);
    try testing.expectEqualStrings("add", executor.history.items[1].args[2]);
    try testing.expectEqualStrings("-f", executor.history.items[1].args[3]);
    try testing.expectEqualStrings("/dev/sda3", executor.history.items[1].args[4]);
    try testing.expectEqualStrings("/", executor.history.items[1].args[5]);

    // 3. Remove Btrfs device
    try executor.removeBtrfsDevice("/dev/sdb1", "/mnt/pool");
    try testing.expectEqual(@as(usize, 3), executor.history.items.len);
    try testing.expectEqualStrings("remove", executor.history.items[2].args[2]);
    try testing.expectEqualStrings("/dev/sdb1", executor.history.items[2].args[3]);

    // 4. Kexec jump
    try executor.executeKexecJump();
    try testing.expectEqual(@as(usize, 4), executor.history.items.len);
    try testing.expectEqualStrings("kexec", executor.history.items[3].args[0]);
    try testing.expectEqualStrings("-e", executor.history.items[3].args[1]);
}
