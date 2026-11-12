//! OSCraft — System Safety Tests
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const safety = @import("safety.zig");

test "unit: parse /proc/mounts content and detect mountpoints" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const mock_mounts =
        \\sysfs /sys sysfs rw,nosuid,nodev,noexec,relatime 0 0
        \\proc /proc proc rw,nosuid,nodev,noexec,relatime 0 0
        \\/dev/nvme0n1p2 / btrfs rw,relatime,ssd 0 0
        \\/dev/nvme0n1p1 /boot/efi vfat rw,relatime,fmask=0077 0 0
        \\/dev/nvme0n1p3 none swap sw 0 0
        \\/dev/sda1 /mnt/data ext4 rw,relatime 0 0
    ;

    const entries = try safety.parseProcMounts(allocator, mock_mounts);
    defer allocator.free(entries);

    try testing.expect(entries.len >= 6);

    // Verify root is protected
    try testing.expectError(
        error.ProtectedRootPartition,
        safety.assertNotProtected(entries, "/dev/nvme0n1p2"),
    );

    // Verify ESP is protected
    try testing.expectError(
        error.ProtectedEspPartition,
        safety.assertNotProtected(entries, "/dev/nvme0n1p1"),
    );

    // Verify swap is protected
    try testing.expectError(
        error.ProtectedSwapDevice,
        safety.assertNotProtected(entries, "/dev/nvme0n1p3"),
    );

    // Verify non-system data partition is not flagged as protected
    try safety.assertNotProtected(entries, "/dev/sda1");

    // Verify completely unmounted device is safe
    try safety.assertNotProtected(entries, "/dev/sda3");
}

test "unit: gpt backup plan creates proper filename and dd arguments" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const plan = safety.GptBackupPlan{
        .disk_device = "/dev/nvme0n1",
        .backup_directory = "/var/lib/oscraft/backups",
    };

    const filename = try plan.formatFilename(allocator, 1731384000);
    defer allocator.free(filename);

    try testing.expectEqualStrings("gpt_backup_nvme0n1_1731384000.bin", filename);

    const args = try plan.buildBackupArgs(allocator, "/tmp/backup.bin");
    defer {
        allocator.free(args[1]);
        allocator.free(args[2]);
        allocator.free(args);
    }

    try testing.expectEqual(@as(usize, 5), args.len);
    try testing.expectEqualStrings("dd", args[0]);
    try testing.expectEqualStrings("if=/dev/nvme0n1", args[1]);
    try testing.expectEqualStrings("of=/tmp/backup.bin", args[2]);
    try testing.expectEqualStrings("bs=512", args[3]);
    try testing.expectEqualStrings("count=34", args[4]);
}
