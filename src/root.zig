//! OSCraft — Core Module Registry
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const Io = std.Io;

const disk_test = @import("storage/disk_test.zig");
const btrfs_test = @import("storage/btrfs_test.zig");

pub const storage = struct {
    pub const disk = @import("storage/disk.zig");
    pub const btrfs = @import("storage/btrfs.zig");
};

pub fn printBanner(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.print("OSCraft: Dynamic Partitioning, Boot Hygiene & Live kexec Engine\n", .{});
}

test {
    _ = storage.disk;
    _ = storage.btrfs;
    _ = disk_test;
    _ = btrfs_test;
}
