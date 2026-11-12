//! OSCraft — CLI Scan Command Tests
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const zli = @import("zli");
const scan_cmd = @import("scan.zig");

test "unit: scan command registration and flags" {
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

    const cmd = try scan_cmd.register(init_options);
    defer cmd.deinit();

    try testing.expectEqualStrings("scan", cmd.cmd_options.name);
    try testing.expect(cmd.flags_by_name.contains("disk"));
}
