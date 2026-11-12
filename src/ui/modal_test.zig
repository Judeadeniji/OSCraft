//! OSCraft — Modal Component Unit Tests
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const modal = @import("modal.zig");

test "modal: ModalState addCommand and getCommand" {
    var state = modal.ModalState{
        .action = .expand_pool,
        .title = "Expand Pool Dry-Run Preview",
        .summary = "Merge unallocated space into / (Btrfs)",
        .target_node = "/dev/sda",
    };

    try std.testing.expectEqual(@as(usize, 0), state.command_count);

    state.addCommand("sgdisk -n 6:212051968:316909567 -t 6:8300 /dev/sda");
    state.addCommand("partprobe /dev/sda");
    state.addCommand("btrfs device add /dev/sda6 /");

    try std.testing.expectEqual(@as(usize, 3), state.command_count);
    try std.testing.expectEqualStrings("sgdisk -n 6:212051968:316909567 -t 6:8300 /dev/sda", state.getCommand(0));
    try std.testing.expectEqualStrings("partprobe /dev/sda", state.getCommand(1));
    try std.testing.expectEqualStrings("btrfs device add /dev/sda6 /", state.getCommand(2));
    try std.testing.expectEqualStrings("", state.getCommand(3));
}

test "modal: ModalState bounds enforcement" {
    var state = modal.ModalState{
        .action = .boot_clean,
        .title = "Clean Boot Entries",
        .summary = "Remove orphan EFI entries",
        .target_node = "/boot/efi",
    };

    for (0..12) |i| {
        var buf: [32]u8 = undefined;
        const cmd = std.fmt.bufPrint(&buf, "cmd_{d}", .{i}) catch unreachable;
        state.addCommand(cmd);
    }

    // Capacity is 8 commands max
    try std.testing.expectEqual(@as(usize, 8), state.command_count);
    try std.testing.expectEqualStrings("cmd_0", state.getCommand(0));
    try std.testing.expectEqualStrings("cmd_7", state.getCommand(7));
}
