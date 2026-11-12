//! OSCraft — Bootloader & UEFI NVRAM Sanitizer
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");

pub const BootEntry = struct {
    boot_num: u16,
    title: []const u8,
    is_active: bool,
    is_current: bool = false,
    device_path: ?[]const u8 = null,
};

pub const BootManager = struct {
    allocator: std.mem.Allocator,
    current_boot: ?u16 = null,
    timeout_seconds: ?u32 = null,
    boot_order: std.ArrayListUnmanaged(u16),
    entries: std.ArrayListUnmanaged(BootEntry),

    pub fn init(allocator: std.mem.Allocator) BootManager {
        return .{
            .allocator = allocator,
            .current_boot = null,
            .timeout_seconds = null,
            .boot_order = .empty,
            .entries = .empty,
        };
    }

    pub fn deinit(self: *BootManager) void {
        self.boot_order.deinit(self.allocator);
        self.entries.deinit(self.allocator);
    }

    /// Finds a registered boot entry by its 4-digit hexadecimal ID.
    pub fn findEntry(self: BootManager, boot_num: u16) ?BootEntry {
        for (self.entries.items) |entry| {
            if (entry.boot_num == boot_num) return entry;
        }
        return null;
    }

    /// Checks if a boot entry matches the currently booted OS.
    pub fn isCurrentBoot(self: BootManager, boot_num: u16) bool {
        if (self.current_boot) |cur| {
            return cur == boot_num;
        }
        return false;
    }

    /// Parses raw output from `efibootmgr` into structured models.
    pub fn parseOutput(self: *BootManager, output: []const u8) !void {
        var line_iter = std.mem.splitScalar(u8, output, '\n');

        while (line_iter.next()) |raw_line| {
            const line = std.mem.trim(u8, raw_line, " \r\t");
            if (line.len == 0) continue;

            if (std.mem.startsWith(u8, line, "BootCurrent:")) {
                const rest = std.mem.trim(u8, line["BootCurrent:".len..], " \t");
                self.current_boot = std.fmt.parseInt(u16, rest, 16) catch null;
            } else if (std.mem.startsWith(u8, line, "Timeout:")) {
                const rest = std.mem.trim(u8, line["Timeout:".len..], " \t");
                var num_len: usize = 0;
                while (num_len < rest.len and std.ascii.isDigit(rest[num_len])) : (num_len += 1) {}
                if (num_len > 0) {
                    self.timeout_seconds = std.fmt.parseInt(u32, rest[0..num_len], 10) catch null;
                }
            } else if (std.mem.startsWith(u8, line, "BootOrder:")) {
                const rest = std.mem.trim(u8, line["BootOrder:".len..], " \t");
                var order_iter = std.mem.splitScalar(u8, rest, ',');
                while (order_iter.next()) |item| {
                    const trimmed_item = std.mem.trim(u8, item, " \t");
                    if (trimmed_item.len > 0) {
                        const num = std.fmt.parseInt(u16, trimmed_item, 16) catch continue;
                        try self.boot_order.append(self.allocator, num);
                    }
                }
            } else if (std.mem.startsWith(u8, line, "Boot")) {
                // Example format: "Boot0001* Arch Linux\tHD(1,GPT,...)/\EFI\arch\grubx64.efi"
                const after_boot = line["Boot".len..];
                if (after_boot.len >= 4) {
                    const hex_slice = after_boot[0..4];
                    const num = std.fmt.parseInt(u16, hex_slice, 16) catch continue;

                    var rest = after_boot[4..];
                    var is_active = false;
                    if (rest.len > 0 and rest[0] == '*') {
                        is_active = true;
                        rest = rest[1..];
                    }
                    rest = std.mem.trim(u8, rest, " \t");

                    // Title is up to the first tab or path marker
                    var title = rest;
                    var path: ?[]const u8 = null;

                    if (std.mem.indexOfScalar(u8, rest, '\t')) |tab_idx| {
                        title = std.mem.trim(u8, rest[0..tab_idx], " ");
                        path = std.mem.trim(u8, rest[tab_idx + 1 ..], " ");
                    }

                    const is_cur = (self.current_boot != null and self.current_boot.? == num);

                    try self.entries.append(self.allocator, .{
                        .boot_num = num,
                        .title = title,
                        .is_active = is_active,
                        .is_current = is_cur,
                        .device_path = path,
                    });
                }
            }
        }
    }

    /// Constructs safe arguments for deleting an NVRAM boot entry (`efibootmgr -b <XXXX> -B`).
    /// Refuses to delete the currently running OS boot entry without explicit override.
    pub fn buildDeleteArgs(
        self: BootManager,
        allocator: std.mem.Allocator,
        boot_num: u16,
        force_current: bool,
    ) ![]const []const u8 {
        if (!force_current and self.isCurrentBoot(boot_num)) {
            return error.CannotDeleteCurrentBootEntry;
        }

        const hex_buf = try std.fmt.allocPrint(allocator, "{X:0>4}", .{boot_num});
        errdefer allocator.free(hex_buf);

        return allocator.dupe([]const u8, &.{
            "efibootmgr", "-b", hex_buf, "-B",
        });
    }

    /// Constructs safe arguments for reordering NVRAM boot sequence (`efibootmgr -o XXXX,YYYY,...`).
    pub fn buildReorderArgs(
        allocator: std.mem.Allocator,
        order: []const u16,
    ) ![]const []const u8 {
        if (order.len == 0) return error.EmptyBootOrder;

        var str_list: std.ArrayList(u8) = .empty;
        defer str_list.deinit(allocator);

        for (order, 0..) |num, i| {
            if (i > 0) try str_list.append(allocator, ',');
            var buf: [4]u8 = undefined;
            const formatted = try std.fmt.bufPrint(&buf, "{X:0>4}", .{num});
            try str_list.appendSlice(allocator, formatted);
        }

        const order_str = try str_list.toOwnedSlice(allocator);
        errdefer allocator.free(order_str);

        return allocator.dupe([]const u8, &.{
            "efibootmgr", "-o", order_str,
        });
    }
};

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    if (needle.len == 0) return true;
    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        if (std.ascii.eqlIgnoreCase(haystack[i .. i + needle.len], needle)) {
            return true;
        }
    }
    return false;
}

/// Compares directories inside ESP `/boot/efi/EFI/` against active boot entries to discover abandoned OS installations.
pub fn detectOrphanEfiDirectories(
    allocator: std.mem.Allocator,
    esp_directories: []const []const u8,
    entries: []const BootEntry,
) ![]const []const u8 {
    var orphans: std.ArrayList([]const u8) = .empty;
    defer orphans.deinit(allocator);

    for (esp_directories) |dir| {
        // Universal ESP folders that must never be considered orphans
        if (std.ascii.eqlIgnoreCase(dir, "BOOT") or
            std.ascii.eqlIgnoreCase(dir, "Microsoft") or
            std.ascii.eqlIgnoreCase(dir, "systemd") or
            std.ascii.eqlIgnoreCase(dir, "System Volume Information"))
        {
            continue;
        }

        var matched = false;
        for (entries) |entry| {
            // Check if directory matches entry title
            if (containsIgnoreCase(entry.title, dir)) {
                matched = true;
                break;
            }
            // Check if directory matches entry device path
            if (entry.device_path) |path| {
                if (containsIgnoreCase(path, dir)) {
                    matched = true;
                    break;
                }
            }
        }

        if (!matched) {
            try orphans.append(allocator, dir);
        }
    }

    return orphans.toOwnedSlice(allocator);
}

/// Builds the argument list for safely removing an orphaned EFI directory.
pub fn buildRemoveOrphanDirArgs(
    allocator: std.mem.Allocator,
    esp_root: []const u8,
    dir_name: []const u8,
) ![]const []const u8 {
    // Safety guardrails: reject empty or sensitive path traversal
    if (dir_name.len == 0 or
        std.mem.eql(u8, dir_name, ".") or
        std.mem.eql(u8, dir_name, "..") or
        std.mem.indexOfScalar(u8, dir_name, '/') != null or
        std.ascii.eqlIgnoreCase(dir_name, "BOOT") or
        std.ascii.eqlIgnoreCase(dir_name, "Microsoft"))
    {
        return error.InvalidOrphanDirectory;
    }

    const full_path = try std.fs.path.join(allocator, &.{ esp_root, "EFI", dir_name });
    errdefer allocator.free(full_path);

    return allocator.dupe([]const u8, &.{
        "rm", "-rf", full_path,
    });
}
