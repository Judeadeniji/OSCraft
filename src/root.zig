//! OSCraft — Core Module Registry
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const disk_mod = @import("storage/disk.zig");
const btrfs_mod = @import("storage/btrfs.zig");
const storage_probe_mod = @import("storage/probe.zig");
const efi_mod = @import("boot/efi.zig");
const kexec_mod = @import("boot/kexec.zig");
const loopback_mod = @import("boot/loopback.zig");
const boot_probe_mod = @import("boot/probe.zig");
const iso_mod = @import("boot/iso.zig");
const cli_mod = @import("cli/root.zig");
const safety_mod = @import("system/safety.zig");
const exec_mod = @import("system/exec.zig");

const disk_test = @import("storage/disk_test.zig");
const btrfs_test = @import("storage/btrfs_test.zig");
const storage_probe_test = @import("storage/probe_test.zig");
const efi_test = @import("boot/efi_test.zig");
const kexec_test = @import("boot/kexec_test.zig");
const loopback_test = @import("boot/loopback_test.zig");
const boot_probe_test = @import("boot/probe_test.zig");
const iso_test = @import("boot/iso_test.zig");
const cli_test = @import("cli/root_test.zig");
const scan_test = @import("cli/scan_test.zig");
const boot_clean_test = @import("cli/boot_clean_test.zig");
const kexec_stage_test = @import("cli/kexec_stage_test.zig");
const loopback_gen_test = @import("cli/loopback_gen_test.zig");
const safety_test = @import("system/safety_test.zig");
const exec_test = @import("system/exec_test.zig");

const Io = std.Io;

pub const storage = struct {
    pub const disk = disk_mod;
    pub const btrfs = btrfs_mod;
    pub const probe = storage_probe_mod;
};

pub const boot = struct {
    pub const efi = efi_mod;
    pub const kexec = kexec_mod;
    pub const loopback = loopback_mod;
    pub const probe = boot_probe_mod;
    pub const iso = iso_mod;
};

pub const system = struct {
    pub const safety = safety_mod;
    pub const exec = exec_mod;
};

pub const cli = struct {
    pub const root = cli_mod;
};

pub fn printBanner(writer: *Io.Writer) Io.Writer.Error!void {
    try writer.print("OSCraft: Dynamic Partitioning, Boot Hygiene & Live kexec Engine\n", .{});
}

test {
    _ = storage.disk;
    _ = storage.btrfs;
    _ = storage.probe;
    _ = boot.efi;
    _ = boot.kexec;
    _ = boot.loopback;
    _ = boot.probe;
    _ = boot.iso;
    _ = system.safety;
    _ = system.exec;
    _ = cli.root;
    _ = disk_test;
    _ = btrfs_test;
    _ = storage_probe_test;
    _ = efi_test;
    _ = kexec_test;
    _ = loopback_test;
    _ = boot_probe_test;
    _ = iso_test;
    _ = cli_test;
    _ = scan_test;
    _ = boot_clean_test;
    _ = kexec_stage_test;
    _ = loopback_gen_test;
    _ = safety_test;
    _ = exec_test;
}
