//! OSCraft — Dry-Run Confirmation Modal Component
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const nanoui = @import("nanoui");

const ui = nanoui.ui;

pub const ModalAction = enum {
    boot_clean,
    expand_pool,
    kexec_boot,
    install_iso,
};

pub const ModalState = struct {
    action: ModalAction,
    title: []const u8,
    summary: []const u8,
    target_node: []const u8,
    commands_buf: [8][128]u8 = undefined,
    commands_len: [8]usize = @splat(0),
    command_count: usize = 0,
    applied: bool = false,

    pub fn addCommand(self: *ModalState, cmd: []const u8) void {
        if (self.command_count >= self.commands_buf.len) return;
        const idx = self.command_count;
        const copy_len = @min(cmd.len, self.commands_buf[idx].len);
        @memcpy(self.commands_buf[idx][0..copy_len], cmd[0..copy_len]);
        self.commands_len[idx] = copy_len;
        self.command_count += 1;
    }

    pub fn getCommand(self: *const ModalState, idx: usize) []const u8 {
        if (idx >= self.command_count) return "";
        return self.commands_buf[idx][0..self.commands_len[idx]];
    }
};

/// Renders the modal overlay dialog in the nanoui context.
pub fn renderModal(state: *ModalState, c: *ui.Context, app_state: anytype) void {
    // Backdrop overlay
    ui.column(c, .{
        .width = .fill,
        .grow = 1,
        .padding = .all(24),
        .justify = .center,
        .align_items = .center,
    });
    defer ui.end(c);

    // Modal dialog card
    ui.column(c, .{
        .width = .{ .px = 580 },
        .background = c.theme.surface,
        .border = c.theme.border,
        .radius = 12,
        .padding = .all(20),
        .gap = 14,
        .shadow = .{ .color = c.theme.shadow, .blur = 24, .y = 8 },
    });
    defer ui.end(c);

    // Header row
    ui.row(c, .{ .width = .fill, .align_items = .center });
    {
        defer ui.end(c);
        ui.text(c, state.title, .{ .size = 17, .weight = .bold });
        ui.spacer(c);
        const close_btn = ui.button(c, "✕", .{ .size = 12, .variant = .secondary });
        if (close_btn.clicked) {
            app_state.modal_state = null;
        }
    }

    // Target badge & summary
    ui.row(c, .{ .gap = 8, .align_items = .center });
    {
        defer ui.end(c);
        ui.text(c, "Target Device:", .{ .size = 12, .weight = .semibold, .color = c.theme.muted });
        ui.text(c, state.target_node, .{ .size = 12, .weight = .bold, .color = c.theme.accent });
    }

    ui.text(c, state.summary, .{ .size = 13, .wrap = true });

    // Warning Banner
    ui.row(c, .{
        .width = .fill,
        .background = ui.Color.hex(0x451a03), // dark amber
        .padding = .xy(12, 8),
        .radius = 6,
        .gap = 8,
        .align_items = .center,
    });
    {
        defer ui.end(c);
        ui.text(c, "⚠ SAFETY GUARD:", .{ .size = 12, .weight = .bold, .color = ui.Color.hex(0xfbbf24) });
        ui.text(c, "GPT header backup is saved to /var/lib/oscraft/backups/ before changes.", .{
            .size = 11,
            .color = ui.Color.hex(0xfef3c7),
        });
    }

    // Commands List Box
    ui.column(c, .{
        .width = .fill,
        .background = ui.Color.hex(0x0f172a), // slate 900
        .padding = .all(12),
        .radius = 6,
        .gap = 6,
    });
    {
        defer ui.end(c);
        ui.text(c, "Planned Command Sequence (Dry-Run):", .{
            .size = 11,
            .weight = .semibold,
            .color = ui.Color.hex(0x94a3b8),
        });

        for (0..state.command_count) |i| {
            ui.keyInt(c, i);
            ui.row(c, .{ .gap = 6 });
            {
                defer ui.end(c);
                ui.textf(c, .{ .size = 12, .color = ui.Color.hex(0x64748b) }, "{d}.", .{i + 1});
                ui.text(c, state.getCommand(i), .{
                    .size = 12,
                    .weight = .medium,
                    .color = ui.Color.hex(0x38bdf8),
                });
            }
        }
    }

    // Action button row
    ui.row(c, .{ .width = .fill, .gap = 10, .justify = .end });
    {
        defer ui.end(c);
        const cancel_btn = ui.button(c, "Cancel", .{ .variant = .secondary });
        if (cancel_btn.clicked) {
            app_state.modal_state = null;
        }

        const apply_btn = ui.button(c, "Execute Transaction", .{ .variant = .primary });
        if (apply_btn.clicked) {
            state.applied = true;
            app_state.setStatus("Transaction dispatched: {s} ({d} commands)", .{ state.title, state.command_count });
            app_state.modal_state = null;
        }
    }
}
