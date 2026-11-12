//! OSCraft — CLI Loopback Gen Command Module
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const zli = @import("zli");
const loopback = @import("../boot/loopback.zig");
const kexec = @import("../boot/kexec.zig");
const iso = @import("../boot/iso.zig");

pub fn register(init_options: zli.InitOptions) !*zli.Command {
    const cmd = try zli.Command.init(init_options, .{
        .name = "loopback-gen",
        .description = "Generate GRUB 2 loopback menuentry to boot ISOs without a physical USB",
    }, execute);

    try cmd.addPositionalArg(.{
        .name = "iso",
        .description = "Absolute path to ISO image on disk",
        .required = true,
    });

    try cmd.addFlag(.{
        .name = "title",
        .shortcut = "t",
        .description = "Menuentry display title in GRUB",
        .type = .String,
        .default_value = .{ .String = "" },
    });

    try cmd.addFlag(.{
        .name = "flavor",
        .shortcut = "f",
        .description = "Distribution flavor: auto, ubuntu, arch, fedora, generic",
        .type = .String,
        .default_value = .{ .String = "auto" },
    });

    return cmd;
}

pub fn execute(ctx: zli.CommandContext) !void {
    const iso_path = ctx.getArg("iso") orelse return error.MissingIsoArgument;
    const title_flag = ctx.flag("title", []const u8);
    const flavor_flag = ctx.flag("flavor", []const u8);

    var flavor = kexec.DistroFlavor.generic;
    var kernel_path: []const u8 = "/vmlinuz";
    var initrd_path: []const u8 = "/initrd";

    if (std.mem.eql(u8, flavor_flag, "auto")) {
        // Auto-detect distro flavor from ISO filename or header
        flavor = iso.detectDistroFlavor(iso_path);
        const resolved = iso.resolvePathsForFlavor(flavor);
        kernel_path = resolved.kernel;
        initrd_path = resolved.initrd;
    } else if (std.ascii.eqlIgnoreCase(flavor_flag, "ubuntu")) {
        flavor = .ubuntu_casper;
        kernel_path = "/casper/vmlinuz";
        initrd_path = "/casper/initrd";
    } else if (std.ascii.eqlIgnoreCase(flavor_flag, "arch")) {
        flavor = .arch_iso;
        kernel_path = "/arch/boot/x86_64/vmlinuz-linux";
        initrd_path = "/arch/boot/x86_64/initramfs-linux.img";
    } else if (std.ascii.eqlIgnoreCase(flavor_flag, "fedora")) {
        flavor = .fedora_dracut;
        kernel_path = "/images/pxeboot/vmlinuz";
        initrd_path = "/images/pxeboot/initrd.img";
    }

    const title = if (title_flag.len > 0)
        title_flag
    else
        try std.fmt.allocPrint(ctx.allocator, "Live OS ({s})", .{@tagName(flavor)});
    defer if (title_flag.len == 0) ctx.allocator.free(title);

    const entry = loopback.IsoEntry{
        .title = title,
        .iso_path = iso_path,
        .kernel_in_iso = kernel_path,
        .initrd_in_iso = initrd_path,
        .flavor = flavor,
    };

    const stanza = try loopback.generateGrubStanza(ctx.allocator, entry);
    defer ctx.allocator.free(stanza);

    try ctx.writer.print("Generated GRUB 2 Stanza (append to /etc/grub.d/40_custom):\n\n{s}", .{stanza});
}
