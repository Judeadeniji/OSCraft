//! OSCraft — Native GUI Application Root
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const nanoui = @import("nanoui");
const disk = @import("../storage/disk.zig");
const probe = @import("../storage/probe.zig");
const partition_bar = @import("partition_bar.zig");
const action_panel = @import("action_panel.zig");
const modal = @import("modal.zig");

const ui = nanoui.ui;

/// Application state shared across all view frames.
pub const AppState = struct {
    allocator: std.mem.Allocator,
    /// Probed disks dynamically allocated.
    disks_list: []disk.Disk,
    /// Index into `disks_list` of currently selected disk (-1 = none).
    selected_disk: i32,
    /// Modal state: null means no modal is showing.
    modal_state: ?modal.ModalState,
    /// Status message shown at the bottom.
    status_buf: [256]u8,
    status_len: usize,

    /// Initialise with an allocator; disks probed via `refresh`.
    pub fn init(allocator: std.mem.Allocator) AppState {
        var s = AppState{
            .allocator = allocator,
            .disks_list = &[_]disk.Disk{},
            .selected_disk = -1,
            .modal_state = null,
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

    /// Re-probe disks from /sys/block.
    pub fn refresh(self: *AppState, io: std.Io) void {
        self.deinit();
        self.disks_list = probe.probeAllDisks(self.allocator, io) catch &[_]disk.Disk{};
        if (self.disks_list.len > 0) {
            self.selected_disk = 0;
            self.refreshGaps();
            self.setStatus("Discovered {d} physical block device(s).", .{self.disks_list.len});
        } else {
            self.selected_disk = -1;
            self.setStatus("No physical block devices detected in /sys/block.", .{});
        }
    }

    /// Recalculate gaps for the currently selected disk.
    pub fn refreshGaps(self: *AppState) void {
        if (self.selectedDisk()) |d| {
            d.calculateGaps() catch return;
        }
    }

    /// Set the status line (truncated to 255 bytes).
    pub fn setStatus(self: *AppState, comptime fmt: []const u8, args: anytype) void {
        const written = std.fmt.bufPrint(&self.status_buf, fmt, args) catch self.status_buf[0..0];
        self.status_len = written.len;
    }

    /// The main view function called every frame by nanoui.
    pub fn view(self: *AppState, c: *ui.Context) void {
        ui.column(c, .{ .width = .fill, .height = .fill });
        defer ui.end(c);

        renderHeader(c);

        if (self.modal_state != null) {
            modal.renderModal(&self.modal_state.?, c, self);
        } else {
            self.renderBody(c);
        }

        self.renderStatusBar(c);
    }

    fn renderHeader(c: *ui.Context) void {
        ui.row(c, .{
            .width = .fill,
            .padding = .xy(16, 10),
            .background = c.theme.surface,
            .border = c.theme.border,
            .align_items = .center,
        });
        defer ui.end(c);

        ui.text(c, "OSCraft", .{ .size = 20, .weight = .bold });
        ui.spacer(c);
        ui.text(c, "Live Disk Manager & Zero-Reboot Engine", .{ .size = 13, .color = c.theme.muted });
    }

    fn renderBody(self: *AppState, c: *ui.Context) void {
        ui.scroll(c, .{ .width = .fill, .grow = 1, .padding = .all(16), .gap = 16 });
        defer ui.end(c);

        self.renderDiskSelector(c);

        if (self.selectedDisk()) |d| {
            partition_bar.renderPartitionBar(d, d.gaps.items, c);
        } else {
            ui.text(c, "No target disk selected.", .{ .size = 14, .color = c.theme.muted });
        }

        action_panel.renderActionPanel(self, c);
    }

    fn renderDiskSelector(self: *AppState, c: *ui.Context) void {
        ui.row(c, .{ .width = .fill, .gap = 8, .align_items = .center });
        defer ui.end(c);

        ui.text(c, "Disks:", .{ .size = 14, .weight = .semibold });
        for (self.disks_list, 0..) |d, i| {
            ui.keyInt(c, i);
            const idx: i32 = @intCast(i);
            const selected = self.selected_disk == idx;
            const it = ui.button(c, d.name, .{
                .variant = if (selected) .primary else .secondary,
            });
            if (it.clicked) {
                self.selected_disk = idx;
                self.refreshGaps();
                self.setStatus("Selected disk: /dev/{s}", .{d.name});
            }
        }

        if (self.disks_list.len == 0) {
            ui.text(c, "No physical disks found.", .{ .size = 13, .color = c.theme.muted });
        }
    }

    fn renderStatusBar(self: *AppState, c: *ui.Context) void {
        ui.row(c, .{
            .width = .fill,
            .padding = .xy(12, 6),
            .background = c.theme.surface,
            .border = c.theme.border,
        });
        defer ui.end(c);
        ui.text(c, self.status(), .{ .size = 12, .color = c.theme.muted });
    }
};

/// Entry point for `zig build gui` — called from `src/gui_main.zig`.
pub fn run(init: std.process.Init) !void {
    const allocator = init.gpa;

    var state = AppState.init(allocator);
    defer state.deinit();

    state.refresh(init.io);

    const app = try nanoui.App.create(init, .{ .name = "OSCraft" });
    defer app.destroy();

    _ = try app.newWindow(.{
        .title = "OSCraft — Live Disk Manager",
        .width = 920,
        .height = 640,
        .content = .{ .view = ui.View.init(&state, AppState.view) },
    });

    try app.run();
}
