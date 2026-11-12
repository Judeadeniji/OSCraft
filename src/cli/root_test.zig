//! OSCraft — CLI Interface Tests
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const zli = @import("zli");
const cli_root = @import("root.zig");

test "flow: cli command tree initialization and registration" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var out_buf: [2048]u8 = undefined;
    var writer = std.Io.Writer.fixed(&out_buf);

    var in_buf: [64]u8 = undefined;
    var reader = std.Io.Reader.fixed(&in_buf);

    const init_options = zli.InitOptions{
        .allocator = allocator,
        .io = testing.io,
        .writer = &writer,
        .reader = &reader,
    };

    const root = try cli_root.initCli(init_options);
    defer root.deinit();

    try testing.expectEqualStrings("oscraft", root.cmd_options.name);
    try testing.expect(root.commands_by_name.count() >= 5);

    // Verify scan subcommand
    const scan_cmd = root.findCommand("scan");
    try testing.expect(scan_cmd != null);
    try testing.expect(scan_cmd.?.flags_by_name.contains("disk"));

    // Verify expand subcommand
    const expand_cmd = root.findCommand("expand");
    try testing.expect(expand_cmd != null);
    try testing.expect(expand_cmd.?.flags_by_name.contains("disk"));
    try testing.expect(expand_cmd.?.flags_by_name.contains("mount"));
    try testing.expect(expand_cmd.?.flags_by_name.contains("size"));
    try testing.expect(expand_cmd.?.flags_by_name.contains("dry-run"));

    // Verify boot-clean subcommand
    const boot_clean_cmd = root.findCommand("boot-clean");
    try testing.expect(boot_clean_cmd != null);
    try testing.expect(boot_clean_cmd.?.flags_by_name.contains("esp"));
    try testing.expect(boot_clean_cmd.?.flags_by_name.contains("dry-run"));

    // Verify kexec-stage subcommand
    const kexec_cmd = root.findCommand("kexec-stage");
    try testing.expect(kexec_cmd != null);
    try testing.expect(kexec_cmd.?.flags_by_name.contains("cmdline"));

    // Verify loopback-gen subcommand
    const loopback_cmd = root.findCommand("loopback-gen");
    try testing.expect(loopback_cmd != null);
    try testing.expect(loopback_cmd.?.flags_by_name.contains("title"));
    try testing.expect(loopback_cmd.?.flags_by_name.contains("flavor"));
}
