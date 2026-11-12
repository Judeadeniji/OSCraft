//! OSCraft — Proportional Partition Bar Component
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const nanoui = @import("nanoui");
const disk = @import("../storage/disk.zig");

const ui = nanoui.ui;

pub const SegmentKind = enum {
    partition,
    gap,
};

pub const BarSegment = struct {
    kind: SegmentKind,
    start_sector: u64,
    end_sector: u64,
    size_sectors: u64,
    size_bytes: u64,
    label: [32]u8 = undefined,
    label_len: usize = 0,
    size_str: [24]u8 = undefined,
    size_str_len: usize = 0,
    color: ui.Color,

    pub fn getLabel(self: *const BarSegment) []const u8 {
        return self.label[0..self.label_len];
    }

    pub fn getSizeStr(self: *const BarSegment) []const u8 {
        return self.size_str[0..self.size_str_len];
    }
};

/// Formats a byte count into a human-readable string (e.g. "512 MB", "450.0 GiB").
pub fn formatSize(bytes: u64, buf: []u8) []const u8 {
    const fbytes: f64 = @floatFromInt(bytes);
    if (bytes >= 1024 * 1024 * 1024) {
        const gib = fbytes / (1024.0 * 1024.0 * 1024.0);
        return std.fmt.bufPrint(buf, "{d:.1} GiB", .{gib}) catch buf[0..0];
    } else if (bytes >= 1024 * 1024) {
        const mib = fbytes / (1024.0 * 1024.0);
        return std.fmt.bufPrint(buf, "{d:.0} MiB", .{mib}) catch buf[0..0];
    } else {
        const kib = fbytes / 1024.0;
        return std.fmt.bufPrint(buf, "{d:.0} KiB", .{kib}) catch buf[0..0];
    }
}

/// Builds an ordered list of bar segments (both partitions and gaps) from a Disk.
pub fn buildSegments(d: *const disk.Disk, out: []BarSegment) usize {
    var count: usize = 0;

    // Collect partitions
    for (d.partitions.items) |part| {
        if (count >= out.len) break;
        var seg: BarSegment = undefined;
        seg.kind = .partition;
        seg.start_sector = part.start_sector;
        seg.end_sector = part.endSector();
        seg.size_sectors = part.size_sectors;
        seg.size_bytes = part.size_bytes;

        const name_slice = part.name;
        const copy_len = @min(name_slice.len, seg.label.len);
        @memcpy(seg.label[0..copy_len], name_slice[0..copy_len]);
        seg.label_len = copy_len;

        const sz = formatSize(part.size_bytes, &seg.size_str);
        seg.size_str_len = sz.len;

        // Choose color based on name/label heuristics
        if (std.mem.indexOf(u8, part.name, "1") != null or
            (part.label != null and std.mem.indexOf(u8, part.label.?, "EFI") != null))
        {
            seg.color = ui.Color.hex(0x2563eb); // EFI blue
        } else if (part.mountpoint != null and std.mem.eql(u8, part.mountpoint.?, "/")) {
            seg.color = ui.Color.hex(0x059669); // Root emerald
        } else {
            seg.color = ui.Color.hex(0x475569); // Slate general partition
        }

        out[count] = seg;
        count += 1;
    }

    // Collect gaps
    for (d.gaps.items) |gap| {
        if (count >= out.len) break;
        var seg: BarSegment = undefined;
        seg.kind = .gap;
        seg.start_sector = gap.start_sector;
        seg.end_sector = gap.end_sector;
        seg.size_sectors = gap.size_sectors;
        seg.size_bytes = gap.size_bytes;

        const free_label = "FREE SPACE";
        @memcpy(seg.label[0..free_label.len], free_label);
        seg.label_len = free_label.len;

        const sz = formatSize(gap.size_bytes, &seg.size_str);
        seg.size_str_len = sz.len;
        seg.color = ui.Color.hex(0x1e293b); // Dark slate for unallocated

        out[count] = seg;
        count += 1;
    }

    // Sort segments topologically by start_sector
    if (count > 1) {
        var i: usize = 0;
        while (i < count - 1) : (i += 1) {
            var j: usize = i + 1;
            while (j < count) : (j += 1) {
                if (out[j].start_sector < out[i].start_sector) {
                    const tmp = out[i];
                    out[i] = out[j];
                    out[j] = tmp;
                }
            }
        }
    }

    return count;
}

/// Renders the proportional partition bar into the current nanoui context.
pub fn renderPartitionBar(d: *const disk.Disk, gaps: []const disk.DiskGap, c: *ui.Context) void {
    _ = gaps;

    var segments_buf: [64]BarSegment = undefined;
    const count = buildSegments(d, &segments_buf);
    const segments = segments_buf[0..count];

    // Disk header info card
    ui.column(c, .{
        .width = .fill,
        .background = c.theme.surface,
        .padding = .all(14),
        .radius = 8,
        .border = c.theme.border,
        .gap = 10,
    });
    defer ui.end(c);

    // Title line: Target Disk: /dev/sda (Model: ..., Total: 238.47 GiB)
    ui.row(c, .{ .width = .fill, .align_items = .center });
    {
        defer ui.end(c);
        ui.text(c, "Target Disk: ", .{ .size = 14, .weight = .bold });
        ui.textf(c, .{ .size = 14, .weight = .semibold, .color = c.theme.accent }, "/dev/{s}", .{d.name});
        if (d.model.len > 0) {
            ui.textf(c, .{ .size = 13, .color = c.theme.muted }, "  ({s})", .{d.model});
        }
        ui.spacer(c);
        ui.textf(c, .{ .size = 13, .weight = .medium }, "{d:.2} GiB Total", .{d.totalGiB()});
    }

    // Proportional Visual Bar
    const total_sectors = if (d.size_sectors == 0) 1 else d.size_sectors;
    ui.row(c, .{
        .width = .fill,
        .height = .{ .px = 52 },
        .radius = 6,
        .clip = true,
        .gap = 2,
        .background = c.theme.border,
    });
    {
        defer ui.end(c);
        for (segments, 0..) |seg, idx| {
            ui.keyInt(c, idx);
            const share = @as(f32, @floatFromInt(seg.size_sectors)) / @as(f32, @floatFromInt(total_sectors));
            const flex_grow = @max(share * 1000.0, 1.0);
            const min_w: f32 = if (seg.kind == .gap) 60.0 else 44.0;

            ui.column(c, .{
                .grow = flex_grow,
                .min_width = min_w,
                .height = .fill,
                .background = seg.color,
                .justify = .center,
                .align_items = .center,
                .padding = .xy(4, 2),
            });
            {
                defer ui.end(c);
                ui.text(c, seg.getLabel(), .{ .size = 11, .weight = .bold, .color = ui.Color.white });
                ui.text(c, seg.getSizeStr(), .{ .size = 10, .color = ui.Color.white.alpha(0.85) });
            }
        }
    }

    // Legend & Diagnostics hint
    ui.row(c, .{ .width = .fill, .gap = 12, .align_items = .center });
    {
        defer ui.end(c);
        renderLegendItem(c, ui.Color.hex(0x2563eb), "EFI System");
        renderLegendItem(c, ui.Color.hex(0x059669), "Root Filesystem");
        renderLegendItem(c, ui.Color.hex(0x475569), "Data Partition");
        renderLegendItem(c, ui.Color.hex(0x1e293b), "Unallocated Free Gap");
    }
}

fn renderLegendItem(c: *ui.Context, color: ui.Color, label: []const u8) void {
    ui.row(c, .{ .gap = 6, .align_items = .center });
    defer ui.end(c);

    _ = c.leaf(.{
        .width = .{ .px = 10 },
        .height = .{ .px = 10 },
        .radius = 2,
        .background = color,
    }, .none, null);

    ui.text(c, label, .{ .size = 11, .color = c.theme.muted });
}
