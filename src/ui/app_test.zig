//! OSCraft — Application State Unit Tests
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const disk = @import("../storage/disk.zig");
const app = @import("app.zig");

test "app: AppState initialization and status" {
    const allocator = std.testing.allocator;

    var state = app.AppState.init(allocator);
    defer state.deinit();

    try std.testing.expectEqualStrings("Ready.", state.status());
    try std.testing.expectEqual(@as(usize, 0), state.diskCount());
    try std.testing.expectEqual(@as(i32, -1), state.selected_disk);
    try std.testing.expect(state.selectedDisk() == null);

    state.setStatus("Scanned {d} disks.", .{3});
    try std.testing.expectEqualStrings("Scanned 3 disks.", state.status());
}

test "app: AppState selectedDisk management" {
    const allocator = std.testing.allocator;

    var state = app.AppState.init(allocator);
    defer state.deinit();

    const sda_node = try allocator.dupe(u8, "/dev/sda");
    const sdb_node = try allocator.dupe(u8, "/dev/sdb");

    var fake_disks = try allocator.alloc(disk.Disk, 2);
    fake_disks[0] = disk.Disk{
        .allocator = allocator,
        .name = "sda",
        .node = sda_node,
        .model = "Drive 1",
        .size_sectors = 1000,
        .size_bytes = 1000 * 512,
        .partitions = .empty,
        .gaps = .empty,
    };
    fake_disks[1] = disk.Disk{
        .allocator = allocator,
        .name = "sdb",
        .node = sdb_node,
        .model = "Drive 2",
        .size_sectors = 2000,
        .size_bytes = 2000 * 512,
        .partitions = .empty,
        .gaps = .empty,
    };

    state.disks_list = fake_disks;
    state.selected_disk = 1;

    const sel = state.selectedDisk();
    try std.testing.expect(sel != null);
    try std.testing.expectEqualStrings("sdb", sel.?.name);

    state.selected_disk = -1;
    try std.testing.expect(state.selectedDisk() == null);
}
