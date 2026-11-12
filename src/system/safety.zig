//! OSCraft — System Safety & Partition Guardrails
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");

pub const ProtectedKind = enum {
    root,
    boot,
    esp,
    swap,
};

pub const MountEntry = struct {
    device: []const u8,
    mount_point: []const u8,
    fs_type: []const u8,
};

pub const SafetyError = error{
    ProtectedRootPartition,
    ProtectedBootPartition,
    ProtectedEspPartition,
    ProtectedSwapDevice,
};

/// Validates whether a device path is currently critical to system operation.
/// Returns a specific SafetyError if the device is mounted as a protected path.
pub fn assertNotProtected(mounts: []const MountEntry, target_device: []const u8) SafetyError!void {
    for (mounts) |entry| {
        if (std.mem.eql(u8, entry.device, target_device)) {
            if (std.mem.eql(u8, entry.mount_point, "/")) {
                return error.ProtectedRootPartition;
            }
            if (std.mem.eql(u8, entry.mount_point, "/boot")) {
                return error.ProtectedBootPartition;
            }
            if (std.mem.eql(u8, entry.mount_point, "/boot/efi") or
                std.mem.eql(u8, entry.mount_point, "/efi"))
            {
                return error.ProtectedEspPartition;
            }
            if (std.mem.eql(u8, entry.fs_type, "swap") or
                std.mem.eql(u8, entry.mount_point, "[SWAP]"))
            {
                return error.ProtectedSwapDevice;
            }
        }
    }
}

/// Parses standard Linux /proc/mounts format into a structured slice of MountEntry.
pub fn parseProcMounts(allocator: std.mem.Allocator, content: []const u8) ![]MountEntry {
    var entries = std.ArrayList(MountEntry).empty;
    errdefer entries.deinit(allocator);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \r\t");
        if (trimmed.len == 0 or trimmed[0] == '#') continue;

        var tokens = std.mem.tokenizeScalar(u8, trimmed, ' ');
        const dev = tokens.next() orelse continue;
        const mp = tokens.next() orelse continue;
        const fst = tokens.next() orelse continue;

        try entries.append(allocator, .{
            .device = dev,
            .mount_point = mp,
            .fs_type = fst,
        });
    }

    return entries.toOwnedSlice(allocator);
}

/// GPT Header & Partition Table Backup Manager
pub const GptBackupPlan = struct {
    disk_device: []const u8,
    backup_directory: []const u8 = "/var/lib/oscraft/backups",

    /// Formats a clean, deterministic filename for the GPT backup.
    pub fn formatFilename(self: GptBackupPlan, allocator: std.mem.Allocator, timestamp: i64) ![]const u8 {
        // Extract disk basename, e.g. /dev/sda -> sda
        var basename = self.disk_device;
        if (std.mem.lastIndexOfScalar(u8, self.disk_device, '/')) |idx| {
            basename = self.disk_device[idx + 1 ..];
        }

        return std.fmt.allocPrint(allocator, "gpt_backup_{s}_{d}.bin", .{ basename, timestamp });
    }

    /// Builds the dd command arguments to back up primary GPT (LBA 0-33 = 17,408 bytes).
    pub fn buildBackupArgs(
        self: GptBackupPlan,
        allocator: std.mem.Allocator,
        target_path: []const u8,
    ) ![]const []const u8 {
        const if_arg = try std.fmt.allocPrint(allocator, "if={s}", .{self.disk_device});
        errdefer allocator.free(if_arg);

        const of_arg = try std.fmt.allocPrint(allocator, "of={s}", .{target_path});
        errdefer allocator.free(of_arg);

        const args = try allocator.alloc([]const u8, 5);
        args[0] = "dd";
        args[1] = if_arg;
        args[2] = of_arg;
        args[3] = "bs=512";
        args[4] = "count=34";

        return args;
    }
};
