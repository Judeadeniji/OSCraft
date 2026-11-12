//! OSCraft — Boot Engine: Zero-Reboot kexec Tests
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const kexec = @import("kexec.zig");

test "flow: kexec load arguments construction" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const plan = kexec.KexecStagePlan{
        .kernel_path = "/tmp/vmlinuz",
        .initrd_path = "/tmp/initrd.img",
        .cmdline = "boot=casper iso-scan/filename=/boot/iso/live.iso toram quiet",
    };

    const args = try plan.buildLoadArgs(allocator);
    defer {
        allocator.free(args[3]);
        allocator.free(args[4]);
        allocator.free(args);
    }

    try testing.expectEqual(@as(usize, 5), args.len);
    try testing.expectEqualStrings("kexec", args[0]);
    try testing.expectEqualStrings("-l", args[1]);
    try testing.expectEqualStrings("/tmp/vmlinuz", args[2]);
    try testing.expectEqualStrings("--initrd=/tmp/initrd.img", args[3]);
    try testing.expectEqualStrings("--command-line=boot=casper iso-scan/filename=/boot/iso/live.iso toram quiet", args[4]);
}

test "flow: kexec execution and unload command generation" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const exec_args = try kexec.KexecStagePlan.buildExecuteArgs(allocator);
    defer allocator.free(exec_args);
    try testing.expectEqual(@as(usize, 2), exec_args.len);
    try testing.expectEqualStrings("kexec", exec_args[0]);
    try testing.expectEqualStrings("-e", exec_args[1]);

    const unload_args = try kexec.KexecStagePlan.buildUnloadArgs(allocator);
    defer allocator.free(unload_args);
    try testing.expectEqual(@as(usize, 2), unload_args.len);
    try testing.expectEqualStrings("kexec", unload_args[0]);
    try testing.expectEqualStrings("-u", unload_args[1]);
}

test "flow: safety validation guards against invalid kexec configurations" {
    const testing = std.testing;

    // Missing kernel path
    const no_kernel = kexec.KexecStagePlan{
        .kernel_path = "",
        .initrd_path = "/tmp/initrd",
        .cmdline = "toram",
    };
    try testing.expectError(error.EmptyKernelPath, no_kernel.validate());

    // Missing initrd path
    const no_initrd = kexec.KexecStagePlan{
        .kernel_path = "/tmp/vmlinuz",
        .initrd_path = "",
        .cmdline = "toram",
    };
    try testing.expectError(error.EmptyInitrdPath, no_initrd.validate());

    // Missing live/RAM boot flag (risks immediate kernel panic on USB-less live boot)
    const unsafe_cmdline = kexec.KexecStagePlan{
        .kernel_path = "/tmp/vmlinuz",
        .initrd_path = "/tmp/initrd",
        .cmdline = "quiet splash",
    };
    try testing.expectError(error.MissingLiveRamBootParameter, unsafe_cmdline.validate());
}

test "flow: distribution flavor default commandlines" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const iso = "/boot/iso/ubuntu.iso";

    const ubuntu_cmd = try kexec.DistroFlavor.ubuntu_casper.defaultCmdline(allocator, iso);
    defer allocator.free(ubuntu_cmd);
    try testing.expect(std.mem.indexOf(u8, ubuntu_cmd, "boot=casper") != null);
    try testing.expect(std.mem.indexOf(u8, ubuntu_cmd, "toram") != null);

    const arch_cmd = try kexec.DistroFlavor.arch_iso.defaultCmdline(allocator, iso);
    defer allocator.free(arch_cmd);
    try testing.expect(std.mem.indexOf(u8, arch_cmd, "img_loop=/boot/iso/ubuntu.iso") != null);
    try testing.expect(std.mem.indexOf(u8, arch_cmd, "copytoram=y") != null);

    const fedora_cmd = try kexec.DistroFlavor.fedora_dracut.defaultCmdline(allocator, iso);
    defer allocator.free(fedora_cmd);
    try testing.expect(std.mem.indexOf(u8, fedora_cmd, "rd.live.ram") != null);
}
