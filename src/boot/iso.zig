//! OSCraft — Boot Engine: ISO9660 Inspection & Flavor Auto-Detection
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const kexec = @import("kexec.zig");

pub const IsoSectorSize: usize = 2048;
pub const PvdSector: usize = 16;
pub const PvdOffset: usize = PvdSector * IsoSectorSize; // 32768 (0x8000)

pub const IsoError = error{
    IsoTooSmall,
    InvalidIsoMagic,
};

pub const IsoInspection = struct {
    volume_id: []const u8,
    flavor: kexec.DistroFlavor,
    kernel_in_iso: []const u8,
    initrd_in_iso: []const u8,
    default_cmdline: []const u8,
};

/// Detects distribution flavor from ISO volume identifier or image filename.
pub fn detectDistroFlavor(volume_or_filename: []const u8) kexec.DistroFlavor {
    const s = volume_or_filename;

    if (containsIgnoreCase(s, "ubuntu") or
        containsIgnoreCase(s, "mint") or
        containsIgnoreCase(s, "pop-os") or
        containsIgnoreCase(s, "elementary") or
        containsIgnoreCase(s, "casper"))
    {
        return .ubuntu_casper;
    }

    if (containsIgnoreCase(s, "arch") or
        containsIgnoreCase(s, "manjaro") or
        containsIgnoreCase(s, "endeavour"))
    {
        return .arch_iso;
    }

    if (containsIgnoreCase(s, "fedora") or
        containsIgnoreCase(s, "rhel") or
        containsIgnoreCase(s, "centos") or
        containsIgnoreCase(s, "rocky") or
        containsIgnoreCase(s, "alma"))
    {
        return .fedora_dracut;
    }

    return .generic;
}

/// Resolves standard kernel and initrd paths for a distribution flavor.
pub fn resolvePathsForFlavor(flavor: kexec.DistroFlavor) struct {
    kernel: []const u8,
    initrd: []const u8,
    cmdline: []const u8,
} {
    return switch (flavor) {
        .ubuntu_casper => .{
            .kernel = "/casper/vmlinuz",
            .initrd = "/casper/initrd",
            .cmdline = "boot=casper iso-scan/filename={iso} toram quiet splash",
        },
        .arch_iso => .{
            .kernel = "/arch/boot/x86_64/vmlinuz-linux",
            .initrd = "/arch/boot/x86_64/initramfs-linux.img",
            .cmdline = "img_loop={iso} copytoram quiet",
        },
        .fedora_dracut => .{
            .kernel = "/images/pxeboot/vmlinuz",
            .initrd = "/images/pxeboot/initrd.img",
            .cmdline = "root=live:CDLABEL={vol} rd.live.image rd.live.ram quiet",
        },
        .generic => .{
            .kernel = "/vmlinuz",
            .initrd = "/initrd",
            .cmdline = "toram quiet",
        },
    };
}

/// Inspects the header bytes of an ISO file (at least 34 KiB) and determines its volume ID and paths.
pub fn inspectIsoHeaderBytes(header_data: []const u8, fallback_filename: []const u8) !IsoInspection {
    if (header_data.len < PvdOffset + IsoSectorSize) {
        return error.IsoTooSmall;
    }

    // PVD sector at offset 32768:
    // byte 0 = Type (0x01 for Primary Volume Descriptor)
    // bytes 1..6 = Identifier ("CD001")
    const pvd = header_data[PvdOffset .. PvdOffset + IsoSectorSize];
    if (pvd[0] != 0x01 or !std.mem.eql(u8, pvd[1..6], "CD001")) {
        return error.InvalidIsoMagic;
    }

    // Volume ID is 32 bytes at offset 40 in PVD (offset 32768 + 40 = 32808)
    const raw_vol_id = pvd[40..72];
    const trimmed_vol_id = std.mem.trim(u8, raw_vol_id, " \x00");

    var flavor = detectDistroFlavor(trimmed_vol_id);
    if (flavor == .generic and fallback_filename.len > 0) {
        flavor = detectDistroFlavor(fallback_filename);
    }

    const paths = resolvePathsForFlavor(flavor);

    return IsoInspection{
        .volume_id = trimmed_vol_id,
        .flavor = flavor,
        .kernel_in_iso = paths.kernel,
        .initrd_in_iso = paths.initrd,
        .default_cmdline = paths.cmdline,
    };
}

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.ascii.eqlIgnoreCase(haystack[i .. i + needle.len], needle)) return true;
    }
    return false;
}
