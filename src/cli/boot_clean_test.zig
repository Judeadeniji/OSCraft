//! OSCraft — CLI Boot Clean Command Tests
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const zli = @import("zli");
const boot_clean_cmd = @import("boot_clean.zig");

test "unit: boot-clean command registration and flags" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var out_buf: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&out_buf);

    var in_buf: [64]u8 = undefined;
    var reader = std.Io.Reader.fixed(&in_buf);

    const init_options = zli.InitOptions{
        .allocator = allocator,
        .io = testing.io,
        .writer = &writer,
        .reader = &reader,
    };

    const cmd = try boot_clean_cmd.register(init_options);
    defer cmd.deinit();

    try testing.expectEqualStrings("boot-clean", cmd.cmd_options.name);
    try testing.expect(cmd.flags_by_name.contains("esp"));
    try testing.expect(cmd.flags_by_name.contains("dry-run"));
}
