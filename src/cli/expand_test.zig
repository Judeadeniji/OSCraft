//! OSCraft — CLI Live Storage Expansion Command Tests
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const zli = @import("zli");
const expand_cmd = @import("expand.zig");

test "unit: expand command registration and flags" {
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

    const cmd = try expand_cmd.register(init_options);
    defer cmd.deinit();

    try testing.expectEqualStrings("expand", cmd.cmd_options.name);
    try testing.expect(cmd.flags_by_name.contains("disk"));
    try testing.expect(cmd.flags_by_name.contains("mount"));
    try testing.expect(cmd.flags_by_name.contains("size"));
    try testing.expect(cmd.flags_by_name.contains("dry-run"));
}
