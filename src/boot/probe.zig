//! OSCraft — Boot Engine: Live EFI & ESP Directory Scanner
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const efi = @import("efi.zig");

const Io = std.Io;

pub const ProbeBootError = error{
    EspPathNotFound,
    NotADirectory,
};

/// Reads subdirectories under the EFI System Partition (e.g. /boot/efi/EFI/).
/// Filters out non-directory files and hidden entries.
pub fn scanEspSubdirectories(allocator: std.mem.Allocator, io: Io, esp_efi_path: []const u8) ![]const []const u8 {
    var dir = Io.Dir.openDirAbsolute(io, esp_efi_path, .{ .iterate = true }) catch |err| {
        if (err == error.FileNotFound) return error.EspPathNotFound;
        if (err == error.NotDir) return error.NotADirectory;
        return err;
    };
    defer dir.close(io);

    var entries = std.ArrayList([]const u8).empty;
    defer entries.deinit(allocator);

    var iter = dir.iterate();
    while (try iter.next(io)) |entry| {
        if (entry.kind == .directory) {
            if (entry.name[0] == '.') continue;
            const duped = try allocator.dupe(u8, entry.name);
            try entries.append(allocator, duped);
        }
    }

    return entries.toOwnedSlice(allocator);
}

/// Discovers orphaned EFI subdirectories given simulated or live ESP contents and efibootmgr output.
pub fn detectOrphansFromEspAndOutput(
    allocator: std.mem.Allocator,
    esp_dirs: []const []const u8,
    efibootmgr_output: []const u8,
) ![]const []const u8 {
    var bm = efi.BootManager.init(allocator);
    defer bm.deinit();

    try bm.parseOutput(efibootmgr_output);

    return efi.detectOrphanEfiDirectories(allocator, esp_dirs, bm.entries.items);
}
