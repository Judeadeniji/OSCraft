//! OSCraft — Boot Engine: USB-Less GRUB Loopback Generator
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const kexec = @import("kexec.zig");

pub const IsoEntry = struct {
    title: []const u8,
    iso_path: []const u8,
    kernel_in_iso: []const u8,
    initrd_in_iso: []const u8,
    flavor: kexec.DistroFlavor,
    custom_cmdline: ?[]const u8 = null,

    /// Returns the kernel boot commandline, formatting the ISO path if default.
    pub fn getCmdline(self: IsoEntry, allocator: std.mem.Allocator) ![]const u8 {
        if (self.custom_cmdline) |cmd| {
            return allocator.dupe(u8, cmd);
        }
        return self.flavor.defaultCmdline(allocator, "$isofile");
    }
};

/// Generates a valid GRUB 2 loopback stanza allowing direct boot from an ISO without a USB drive.
pub fn generateGrubStanza(allocator: std.mem.Allocator, entry: IsoEntry) ![]const u8 {
    if (entry.title.len == 0) return error.EmptyEntryTitle;
    if (entry.iso_path.len == 0) return error.EmptyIsoPath;
    if (entry.kernel_in_iso.len == 0) return error.EmptyKernelPath;
    if (entry.initrd_in_iso.len == 0) return error.EmptyInitrdPath;

    const cmdline = try entry.getCmdline(allocator);
    defer allocator.free(cmdline);

    return try std.fmt.allocPrint(
        allocator,
        \\menuentry "{s}" {{
        \\    set isofile="{s}"
        \\    search --no-floppy --set=root --file $isofile
        \\    loopback loop $isofile
        \\    linux (loop){s} {s}
        \\    initrd (loop){s}
        \\}}
        \\
    ,
        .{
            entry.title,
            entry.iso_path,
            entry.kernel_in_iso,
            cmdline,
            entry.initrd_in_iso,
        },
    );
}
