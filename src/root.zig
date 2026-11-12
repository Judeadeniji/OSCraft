//! OSCraft — Core Module Registry
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const disk_mod = @import("storage/disk.zig");
const btrfs_mod = @import("storage/btrfs.zig");
const efi_mod = @import("boot/efi.zig");

const disk_test = @import("storage/disk_test.zig");
const btrfs_test = @import("storage/btrfs_test.zig");
const efi_test = @import("boot/efi_test.zig");

const Io = std.Io;

pub const storage = struct {
    pub const disk = disk_mod;
    pub const btrfs = btrfs_mod;
};

pub const boot = struct {
    pub const efi = efi_mod;
};

pub fn printBanner(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.print("OSCraft: Dynamic Partitioning, Boot Hygiene & Live kexec Engine\n", .{});
}

test {
    _ = storage.disk;
    _ = storage.btrfs;
    _ = boot.efi;
    _ = disk_test;
    _ = btrfs_test;
    _ = efi_test;
}
