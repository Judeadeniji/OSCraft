//! OSCraft — Core Module Registry
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const Io = std.Io;

pub const storage = struct {
    pub const disk = @import("storage/disk.zig");
};

pub fn printBanner(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.print("OSCraft: Dynamic Partitioning, Boot Hygiene & Live kexec Engine\n", .{});
}

test {
    _ = storage.disk;
    _ = @import("storage/disk_test.zig");
}
