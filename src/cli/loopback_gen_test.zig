//! OSCraft — CLI Loopback Gen Command Tests
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const zli = @import("zli");
const loopback_gen_cmd = @import("loopback_gen.zig");

test "unit: loopback-gen command registration and arguments" {
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

    const cmd = try loopback_gen_cmd.register(init_options);
    defer cmd.deinit();

    try testing.expectEqualStrings("loopback-gen", cmd.cmd_options.name);
    try testing.expect(cmd.flags_by_name.contains("title"));
    try testing.expect(cmd.flags_by_name.contains("flavor"));
    try testing.expectEqual(@as(usize, 1), cmd.positional_args.items.len);
    try testing.expectEqualStrings("iso", cmd.positional_args.items[0].name);
}
