//! OSCraft — Boot Engine: ISO9660 Inspection Tests
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const iso = @import("iso.zig");
const kexec = @import("kexec.zig");

test "unit: detect distro flavors from names and labels" {
    const testing = std.testing;

    try testing.expectEqual(kexec.DistroFlavor.ubuntu_casper, iso.detectDistroFlavor("ubuntu-24.04-live-server.iso"));
    try testing.expectEqual(kexec.DistroFlavor.ubuntu_casper, iso.detectDistroFlavor("linuxmint-21.3-cinnamon-64bit.iso"));
    try testing.expectEqual(kexec.DistroFlavor.arch_iso, iso.detectDistroFlavor("archlinux-2026.11.01-x86_64.iso"));
    try testing.expectEqual(kexec.DistroFlavor.arch_iso, iso.detectDistroFlavor("manjaro-kde-23.1.iso"));
    try testing.expectEqual(kexec.DistroFlavor.fedora_dracut, iso.detectDistroFlavor("Fedora-Workstation-Live-x86_64-40.iso"));
    try testing.expectEqual(kexec.DistroFlavor.generic, iso.detectDistroFlavor("custom-rescue-system.iso"));
}

test "unit: inspect synthetic ISO9660 header with PVD" {
    const testing = std.testing;

    // Allocate 35 KiB buffer for synthetic ISO header
    var header_buf: [35 * 1024]u8 = undefined;
    @memset(&header_buf, 0);

    const pvd_offset = iso.PvdOffset;

    // Write PVD type (0x01) and identifier ("CD001")
    header_buf[pvd_offset] = 0x01;
    @memcpy(header_buf[pvd_offset + 1 .. pvd_offset + 6], "CD001");

    // Write Volume Identifier at offset 40 in PVD
    const vol_id = "UBUNTU_24_04_LTS";
    @memcpy(header_buf[pvd_offset + 40 .. pvd_offset + 40 + vol_id.len], vol_id);

    const inspection = try iso.inspectIsoHeaderBytes(&header_buf, "test.iso");

    try testing.expectEqualStrings("UBUNTU_24_04_LTS", inspection.volume_id);
    try testing.expectEqual(kexec.DistroFlavor.ubuntu_casper, inspection.flavor);
    try testing.expectEqualStrings("/casper/vmlinuz", inspection.kernel_in_iso);
    try testing.expectEqualStrings("/casper/initrd", inspection.initrd_in_iso);
}

test "unit: inspect invalid ISO header returns error" {
    const testing = std.testing;

    var header_buf: [35 * 1024]u8 = undefined;
    @memset(&header_buf, 0);

    try testing.expectError(
        error.InvalidIsoMagic,
        iso.inspectIsoHeaderBytes(&header_buf, "bad.iso"),
    );

    var small_buf: [1024]u8 = undefined;
    try testing.expectError(
        error.IsoTooSmall,
        iso.inspectIsoHeaderBytes(&small_buf, "too_small.iso"),
    );
}
