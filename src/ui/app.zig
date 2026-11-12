//! OSCraft — Web UI Host & IPC Subsystem
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const nanoui = @import("nanoui");
const disk = @import("../storage/disk.zig");
const probe = @import("../storage/probe.zig");
const kexec = @import("../boot/kexec.zig");

pub const assets = [_]nanoui.Asset{
    .{
        .path = "/index.html",
        .data = @embedFile("dist/index.html"),
        .mime = "text/html; charset=utf-8",
    },
    .{
        .path = "/assets/index.css",
        .data = @embedFile("dist/assets/index.css"),
        .mime = "text/css; charset=utf-8",
    },
    .{
        .path = "/assets/index.js",
        .data = @embedFile("dist/assets/index.js"),
        .mime = "application/javascript; charset=utf-8",
    },
};

pub const PartitionDto = struct {
    name: []const u8,
    label: []const u8,
    fsType: []const u8,
    sizeBytes: u64,
    mountPoint: ?[]const u8 = null,
    isBoot: bool = false,
};

pub const DiskDto = struct {
    path: []const u8,
    model: []const u8,
    sizeBytes: u64,
    tableType: []const u8,
    partitions: []const PartitionDto,
};

/// Service bound to nanoui webview IPC under the "storage" namespace.
pub const StorageService = struct {
    app_state: *AppState,
    io: std.Io,

    pub const nanoui_params = .{
        .probeDisks = .{},
        .triggerKexec = .{},
    };

    pub fn probeDisks(self: *StorageService) ![]DiskDto {
        self.app_state.refresh(self.io);
        return self.app_state.toDto(self.app_state.allocator);
    }

    pub fn triggerKexec(self: *StorageService) !void {
        _ = self;
    }
};

/// Core application state shared between the host process and webview IPC.
pub const AppState = struct {
    allocator: std.mem.Allocator,
    disks_list: []disk.Disk,
    selected_disk: i32,
    status_buf: [256]u8,
    status_len: usize,

    pub fn init(allocator: std.mem.Allocator) AppState {
        var s = AppState{
            .allocator = allocator,
            .disks_list = &[_]disk.Disk{},
            .selected_disk = -1,
            .status_buf = undefined,
            .status_len = 0,
        };
        const msg = "Ready.";
        @memcpy(s.status_buf[0..msg.len], msg);
        s.status_len = msg.len;
        return s;
    }

    pub fn deinit(self: *AppState) void {
        for (self.disks_list) |*d| {
            probe.freeDisk(d);
        }
        if (self.disks_list.len > 0) {
            self.allocator.free(self.disks_list);
            self.disks_list = &[_]disk.Disk{};
        }
    }

    pub fn status(self: *const AppState) []const u8 {
        return self.status_buf[0..self.status_len];
    }

    pub fn disks(self: *const AppState) []const disk.Disk {
        return self.disks_list;
    }

    pub fn diskCount(self: *const AppState) usize {
        return self.disks_list.len;
    }

    pub fn selectedDisk(self: *AppState) ?*disk.Disk {
        if (self.selected_disk < 0 or self.selected_disk >= self.disks_list.len) return null;
        return &self.disks_list[@intCast(self.selected_disk)];
    }

    pub fn refresh(self: *AppState, io: std.Io) void {
        self.deinit();
        self.disks_list = probe.probeAllDisks(self.allocator, io) catch &[_]disk.Disk{};
        if (self.disks_list.len > 0) {
            self.selected_disk = 0;
            self.setStatus("Found {d} drive(s).", .{self.disks_list.len});
        } else {
            self.selected_disk = -1;
            self.setStatus("No physical drives detected.", .{});
        }
    }

    pub fn setStatus(self: *AppState, comptime fmt: []const u8, args: anytype) void {
        const written = std.fmt.bufPrint(&self.status_buf, fmt, args) catch self.status_buf[0..0];
        self.status_len = written.len;
    }

    /// Serializes probed disks into DTOs for webview consumption.
    pub fn toDto(self: *const AppState, arena: std.mem.Allocator) ![]DiskDto {
        var dtos = try arena.alloc(DiskDto, self.disks_list.len);
        for (self.disks_list, 0..) |d, i| {
            var parts = try arena.alloc(PartitionDto, d.partitions.items.len);
            for (d.partitions.items, 0..) |p, j| {
                parts[j] = .{
                    .name = p.node,
                    .label = p.label orelse p.name,
                    .fsType = p.fstype orelse "unknown",
                    .sizeBytes = p.size_bytes,
                    .mountPoint = p.mountpoint,
                    .isBoot = false,
                };
            }
            dtos[i] = .{
                .path = d.node,
                .model = d.model,
                .sizeBytes = d.size_bytes,
                .tableType = "GPT",
                .partitions = parts,
            };
        }
        return dtos;
    }
};

/// Entry point for `zig17 build gui` — launched from `src/gui_main.zig`.
pub fn run(init: std.process.Init) !void {
    const allocator = init.gpa;

    var state = AppState.init(allocator);
    defer state.deinit();
    state.refresh(init.io);

    const app = try nanoui.App.create(init, .{ .name = "OSCraft" });
    defer app.destroy();

    var storage_service: StorageService = .{
        .app_state = &state,
        .io = init.io,
    };
    try app.bind(&storage_service);

    _ = try app.newWindow(.{
        .title = "OSCraft — Live Disk Manager & Zero-Reboot Engine",
        .width = 1120,
        .height = 760,
        .content = .{
            .page = .{
                .url = "/",
                .assets = &assets,
                .inspectable = true,
            },
        },
    });

    try app.run();
}
