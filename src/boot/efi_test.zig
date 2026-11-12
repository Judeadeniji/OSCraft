//! OSCraft — Bootloader & UEFI NVRAM Sanitizer Tests
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const efi = @import("efi.zig");

test "flow: parse realistic efibootmgr nvram dump" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const mock_output =
        "BootCurrent: 0001\n" ++
        "Timeout: 3 seconds\n" ++
        "BootOrder: 0001,0002,0000,2001\n" ++
        "Boot0000* Fedora Linux\tHD(1,GPT,11111111-2222-3333-4444-555555555555,0x800,0x100000)/\\EFI\\fedora\\shimx64.efi\n" ++
        "Boot0001* Arch Linux\tHD(1,GPT,11111111-2222-3333-4444-555555555555,0x800,0x100000)/\\EFI\\arch\\grubx64.efi\n" ++
        "Boot0002* Defunct OS\tHD(1,GPT,11111111-2222-3333-4444-555555555555,0x800,0x100000)/\\EFI\\defunct\\bootx64.efi\n" ++
        "Boot2001  USB Device (UEFI)\tRC\n";

    var mgr = efi.BootManager.init(allocator);
    defer mgr.deinit();

    try mgr.parseOutput(mock_output);

    // BootCurrent & Timeout checks
    try testing.expect(mgr.current_boot != null);
    try testing.expectEqual(@as(u16, 0x0001), mgr.current_boot.?);
    try testing.expect(mgr.timeout_seconds != null);
    try testing.expectEqual(@as(u32, 3), mgr.timeout_seconds.?);

    // BootOrder check
    try testing.expectEqual(@as(usize, 4), mgr.boot_order.items.len);
    try testing.expectEqual(@as(u16, 0x0001), mgr.boot_order.items[0]);
    try testing.expectEqual(@as(u16, 0x0002), mgr.boot_order.items[1]);
    try testing.expectEqual(@as(u16, 0x0000), mgr.boot_order.items[2]);
    try testing.expectEqual(@as(u16, 0x2001), mgr.boot_order.items[3]);

    // Entries check
    try testing.expectEqual(@as(usize, 4), mgr.entries.items.len);

    const arch_entry = mgr.findEntry(0x0001);
    try testing.expect(arch_entry != null);
    try testing.expectEqualStrings("Arch Linux", arch_entry.?.title);
    try testing.expect(arch_entry.?.is_active);
    try testing.expect(arch_entry.?.is_current);

    const usb_entry = mgr.findEntry(0x2001);
    try testing.expect(usb_entry != null);
    try testing.expectEqualStrings("USB Device (UEFI)", usb_entry.?.title);
    try testing.expect(!usb_entry.?.is_active); // no asterisk
    try testing.expect(!usb_entry.?.is_current);
}

test "flow: safety guardrail prevents deleting current active boot entry" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var mgr = efi.BootManager.init(allocator);
    defer mgr.deinit();

    mgr.current_boot = 0x0001;

    // Attempting to delete current boot entry without force must fail
    const err = mgr.buildDeleteArgs(allocator, 0x0001, false);
    try testing.expectError(error.CannotDeleteCurrentBootEntry, err);

    // Deleting another entry (e.g. 0x0002) succeeds
    const delete_args = try mgr.buildDeleteArgs(allocator, 0x0002, false);
    defer {
        allocator.free(delete_args[2]);
        allocator.free(delete_args);
    }

    try testing.expectEqual(@as(usize, 4), delete_args.len);
    try testing.expectEqualStrings("efibootmgr", delete_args[0]);
    try testing.expectEqualStrings("-b", delete_args[1]);
    try testing.expectEqualStrings("0002", delete_args[2]);
    try testing.expectEqualStrings("-B", delete_args[3]);
}

test "flow: boot order reconstruction arguments" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const new_order = [_]u16{ 0x0002, 0x0001, 0x0000 };
    const reorder_args = try efi.BootManager.buildReorderArgs(allocator, &new_order);
    defer {
        allocator.free(reorder_args[2]);
        allocator.free(reorder_args);
    }

    try testing.expectEqual(@as(usize, 3), reorder_args.len);
    try testing.expectEqualStrings("efibootmgr", reorder_args[0]);
    try testing.expectEqualStrings("-o", reorder_args[1]);
    try testing.expectEqualStrings("0002,0001,0000", reorder_args[2]);
}

test "flow: detect orphaned EFI directories on ESP" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const esp_directories = [_][]const u8{
        "BOOT",
        "Microsoft",
        "arch",
        "fedora",
        "abandoned_os",
    };

    const active_entries = [_]efi.BootEntry{
        .{
            .boot_num = 0x0000,
            .title = "Fedora Linux",
            .is_active = true,
            .device_path = "\\EFI\\fedora\\shimx64.efi",
        },
        .{
            .boot_num = 0x0001,
            .title = "Arch Linux",
            .is_active = true,
            .device_path = "\\EFI\\arch\\grubx64.efi",
        },
    };

    const orphans = try efi.detectOrphanEfiDirectories(allocator, &esp_directories, &active_entries);
    defer allocator.free(orphans);

    // Only "abandoned_os" should be detected as orphan!
    // ("BOOT" and "Microsoft" are protected system folders, "arch" and "fedora" match active entries)
    try testing.expectEqual(@as(usize, 1), orphans.len);
    try testing.expectEqualStrings("abandoned_os", orphans[0]);
}

test "flow: build safe orphan removal arguments with traversal guardrails" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Normal safe deletion
    const rm_args = try efi.buildRemoveOrphanDirArgs(allocator, "/boot/efi", "abandoned_os");
    defer {
        allocator.free(rm_args[2]);
        allocator.free(rm_args);
    }

    try testing.expectEqual(@as(usize, 3), rm_args.len);
    try testing.expectEqualStrings("rm", rm_args[0]);
    try testing.expectEqualStrings("-rf", rm_args[1]);
    try testing.expectEqualStrings("/boot/efi/EFI/abandoned_os", rm_args[2]);

    // Safety guardrails: reject traversal and protected folders
    try testing.expectError(error.InvalidOrphanDirectory, efi.buildRemoveOrphanDirArgs(allocator, "/boot/efi", ".."));
    try testing.expectError(error.InvalidOrphanDirectory, efi.buildRemoveOrphanDirArgs(allocator, "/boot/efi", "BOOT"));
    try testing.expectError(error.InvalidOrphanDirectory, efi.buildRemoveOrphanDirArgs(allocator, "/boot/efi", "sub/dir"));
}
