//! OSCraft — Diagnostics & Action Panel Component
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const nanoui = @import("nanoui");
const disk = @import("../storage/disk.zig");
const expand = @import("../storage/expand.zig");
const modal = @import("modal.zig");

const ui = nanoui.ui;

pub const ActionPlan = struct {
    has_gap: bool,
    gap_bytes: u64,
    largest_gap_start: u64,
    largest_gap_end: u64,
    next_part_num: u32,

    pub fn init(d: *const disk.Disk) ActionPlan {
        var plan = ActionPlan{
            .has_gap = false,
            .gap_bytes = 0,
            .largest_gap_start = 0,
            .largest_gap_end = 0,
            .next_part_num = 1,
        };

        // Determine largest unallocated gap
        for (d.gaps.items) |gap| {
            if (gap.size_bytes > plan.gap_bytes) {
                plan.has_gap = true;
                plan.gap_bytes = gap.size_bytes;
                plan.largest_gap_start = gap.start_sector;
                plan.largest_gap_end = gap.end_sector;
            }
        }

        // Determine next partition number
        var highest: u32 = 0;
        for (d.partitions.items) |p| {
            if (p.part_num > highest) highest = p.part_num;
        }
        plan.next_part_num = highest + 1;

        return plan;
    }
};

/// Renders the Diagnostics & Actions card into the UI context.
pub fn renderActionPanel(app_state: anytype, c: *ui.Context) void {
    ui.column(c, .{
        .width = .fill,
        .background = c.theme.surface,
        .padding = .all(14),
        .radius = 8,
        .border = c.theme.border,
        .gap = 12,
    });
    defer ui.end(c);

    // Section title
    ui.row(c, .{ .width = .fill, .align_items = .center });
    {
        defer ui.end(c);
        ui.text(c, "Diagnostics & One-Click Actions", .{ .size = 14, .weight = .bold });
        ui.spacer(c);
        ui.text(c, "Safety Dry-Run Guaranteed", .{ .size = 11, .color = ui.Color.hex(0x10b981), .weight = .semibold });
    }

    // Action 1: 1-Click Fix (Boot Hygiene)
    renderActionRow(
        c,
        "✦ 1-Click Fix",
        false,
        "Clean orphaned UEFI boot entries and stale ESP subdirectories",
        "Recommended when stale distro entries persist in NVRAM",
        onBootCleanClicked,
        app_state,
    );

    // Action 2: Expand Pool (Live Btrfs Storage Expansion)
    renderActionRow(
        c,
        "⇥ Expand Pool",
        true,
        "Allocate unallocated space and merge into active / (Btrfs)",
        "Zero-downtime online partition creation and device pooling",
        onExpandPoolClicked,
        app_state,
    );

    // Action 3: Quick Boot (kexec Live Switching)
    renderActionRow(
        c,
        "⚡ Quick Boot",
        false,
        "Switch into a live Linux ISO in <3s without hardware reboot",
        "Zero-reboot memory handover via Linux kexec_file_load",
        onQuickBootClicked,
        app_state,
    );

    // Action 4: Install ISO (GRUB Loopback)
    renderActionRow(
        c,
        "+ Install ISO",
        false,
        "Register a live ISO image directly into the GRUB boot menu",
        "USB-less installation: boots loopback ISO directly from disk",
        onInstallIsoClicked,
        app_state,
    );
}

fn renderActionRow(
    c: *ui.Context,
    button_label: []const u8,
    is_primary: bool,
    title: []const u8,
    subtitle: []const u8,
    on_click: fn (app_state: anytype) void,
    app_state: anytype,
) void {
    ui.row(c, .{
        .width = .fill,
        .padding = .xy(10, 8),
        .background = c.theme.background,
        .radius = 6,
        .align_items = .center,
        .gap = 12,
    });
    defer ui.end(c);

    const btn = ui.button(c, button_label, .{
        .variant = if (is_primary) .primary else .secondary,
        .width = .{ .px = 140 },
    });
    if (btn.clicked) {
        on_click(app_state);
    }

    ui.column(c, .{ .gap = 2 });
    {
        defer ui.end(c);
        ui.text(c, title, .{ .size = 13, .weight = .semibold });
        ui.text(c, subtitle, .{ .size = 11, .color = c.theme.muted });
    }
}

fn onBootCleanClicked(app_state: anytype) void {
    var modal_state = modal.ModalState{
        .action = .boot_clean,
        .title = "✦ Clean Boot Hygiene — Dry-Run Preview",
        .summary = "Prune orphaned NVRAM boot entries and obsolete EFI directory trees safely.",
        .target_node = "/boot/efi",
    };

    modal_state.addCommand("efibootmgr -b 0003 -B");
    modal_state.addCommand("rm -rf /boot/efi/EFI/ubuntu");

    app_state.modal_state = modal_state;
    app_state.setStatus("Opened preview: Clean UEFI Boot Entries", .{});
}

fn onExpandPoolClicked(app_state: anytype) void {
    const d = app_state.selectedDisk() orelse {
        app_state.setStatus("Please select a target disk first.", .{});
        return;
    };

    const plan = ActionPlan.init(d);

    var modal_state = modal.ModalState{
        .action = .expand_pool,
        .title = "⇥ Expand Storage Pool — Dry-Run Preview",
        .summary = "Allocate new partition in unallocated space and join it to the active Btrfs pool.",
        .target_node = d.node,
    };

    if (plan.has_gap) {
        var sgdisk_buf: [128]u8 = undefined;
        const sgdisk_cmd = std.fmt.bufPrint(
            &sgdisk_buf,
            "sgdisk -n {d}:{d}:{d} -t {d}:8300 {s}",
            .{ plan.next_part_num, plan.largest_gap_start, plan.largest_gap_end, plan.next_part_num, d.node },
        ) catch "sgdisk -n ...";
        modal_state.addCommand(sgdisk_cmd);

        var probe_buf: [64]u8 = undefined;
        const probe_cmd = std.fmt.bufPrint(&probe_buf, "partprobe {s}", .{d.node}) catch "partprobe";
        modal_state.addCommand(probe_cmd);

        var btrfs_buf: [128]u8 = undefined;
        const btrfs_cmd = std.fmt.bufPrint(
            &btrfs_buf,
            "btrfs device add {s}{d} /",
            .{ d.node, plan.next_part_num },
        ) catch "btrfs device add ... /";
        modal_state.addCommand(btrfs_cmd);
    } else {
        modal_state.addCommand("# Selected disk has no unallocated gaps to expand.");
    }

    app_state.modal_state = modal_state;
    app_state.setStatus("Opened preview: Expand Btrfs Storage Pool", .{});
}

fn onQuickBootClicked(app_state: anytype) void {
    var modal_state = modal.ModalState{
        .action = .kexec_boot,
        .title = "⚡ Zero-Reboot Quick Boot — Dry-Run Preview",
        .summary = "Stage live ISO kernel and initramfs into memory and execute zero-reboot kexec switch.",
        .target_node = "kexec_file_load",
    };

    modal_state.addCommand("kexec -l /boot/vmlinuz-linux --initrd=/boot/initramfs-linux.img --append=\"iso-scan/filename=/live.iso boot=live\"");
    modal_state.addCommand("systemctl kexec");

    app_state.modal_state = modal_state;
    app_state.setStatus("Opened preview: Quick Boot kexec Staging", .{});
}

fn onInstallIsoClicked(app_state: anytype) void {
    var modal_state = modal.ModalState{
        .action = .install_iso,
        .title = "+ Register Loopback ISO — Dry-Run Preview",
        .summary = "Configure persistent GRUB loopback entry for USB-less booting.",
        .target_node = "/boot/grub/grub.cfg",
    };

    modal_state.addCommand("mkdir -p /boot/iso");
    modal_state.addCommand("cp /home/user/archlinux.iso /boot/iso/archlinux.iso");
    modal_state.addCommand("grub-mkconfig -o /boot/grub/grub.cfg");

    app_state.modal_state = modal_state;
    app_state.setStatus("Opened preview: Register Loopback ISO", .{});
}
