//! OSCraft — Boot Engine: USB-Less GRUB Loopback Tests
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const kexec = @import("kexec.zig");
const loopback = @import("loopback.zig");

test "flow: generate valid grub loopback stanza for ubuntu" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const entry = loopback.IsoEntry{
        .title = "Live Ubuntu 24.04 (No USB)",
        .iso_path = "/boot/iso/ubuntu-24.04-desktop-amd64.iso",
        .kernel_in_iso = "/casper/vmlinuz",
        .initrd_in_iso = "/casper/initrd",
        .flavor = kexec.DistroFlavor.ubuntu_casper,
    };

    const stanza = try loopback.generateGrubStanza(allocator, entry);
    defer allocator.free(stanza);

    try testing.expect(std.mem.indexOf(u8, stanza, "menuentry \"Live Ubuntu 24.04 (No USB)\"") != null);
    try testing.expect(std.mem.indexOf(u8, stanza, "set isofile=\"/boot/iso/ubuntu-24.04-desktop-amd64.iso\"") != null);
    try testing.expect(std.mem.indexOf(u8, stanza, "loopback loop $isofile") != null);
    try testing.expect(std.mem.indexOf(u8, stanza, "linux (loop)/casper/vmlinuz boot=casper iso-scan/filename=$isofile toram quiet splash") != null);
    try testing.expect(std.mem.indexOf(u8, stanza, "initrd (loop)/casper/initrd") != null);
}

test "flow: generate valid grub loopback stanza for arch linux" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const entry = loopback.IsoEntry{
        .title = "Arch Linux Live (RAM Boot)",
        .iso_path = "/boot/iso/archlinux.iso",
        .kernel_in_iso = "/arch/boot/x86_64/vmlinuz-linux",
        .initrd_in_iso = "/arch/boot/x86_64/initramfs-linux.img",
        .flavor = kexec.DistroFlavor.arch_iso,
    };

    const stanza = try loopback.generateGrubStanza(allocator, entry);
    defer allocator.free(stanza);

    try testing.expect(std.mem.indexOf(u8, stanza, "menuentry \"Arch Linux Live (RAM Boot)\"") != null);
    try testing.expect(std.mem.indexOf(u8, stanza, "linux (loop)/arch/boot/x86_64/vmlinuz-linux img_loop=$isofile copytoram=y quiet") != null);
    try testing.expect(std.mem.indexOf(u8, stanza, "initrd (loop)/arch/boot/x86_64/initramfs-linux.img") != null);
}

test "flow: custom commandline override" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const entry = loopback.IsoEntry{
        .title = "Custom Rescue OS",
        .iso_path = "/boot/iso/rescue.iso",
        .kernel_in_iso = "/boot/vmlinuz",
        .initrd_in_iso = "/boot/initrd",
        .flavor = kexec.DistroFlavor.generic,
        .custom_cmdline = "custom_param=1 debug toram",
    };

    const stanza = try loopback.generateGrubStanza(allocator, entry);
    defer allocator.free(stanza);

    try testing.expect(std.mem.indexOf(u8, stanza, "custom_param=1 debug toram") != null);
}

test "flow: validation rejects empty parameters" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Empty title
    const no_title = loopback.IsoEntry{
        .title = "",
        .iso_path = "/boot/iso/test.iso",
        .kernel_in_iso = "/vmlinuz",
        .initrd_in_iso = "/initrd",
        .flavor = kexec.DistroFlavor.generic,
    };
    try testing.expectError(error.EmptyEntryTitle, loopback.generateGrubStanza(allocator, no_title));

    // Empty ISO path
    const no_iso = loopback.IsoEntry{
        .title = "Test",
        .iso_path = "",
        .kernel_in_iso = "/vmlinuz",
        .initrd_in_iso = "/initrd",
        .flavor = kexec.DistroFlavor.generic,
    };
    try testing.expectError(error.EmptyIsoPath, loopback.generateGrubStanza(allocator, no_iso));
}
