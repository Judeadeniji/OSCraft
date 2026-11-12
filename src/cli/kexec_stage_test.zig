//! OSCraft — CLI kexec Stage Command Tests
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const zli = @import("zli");
const kexec_stage_cmd = @import("kexec_stage.zig");

test "unit: kexec-stage command registration and arguments" {
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

    const cmd = try kexec_stage_cmd.register(init_options);
    defer cmd.deinit();

    try testing.expectEqualStrings("kexec-stage", cmd.cmd_options.name);
    try testing.expect(cmd.flags_by_name.contains("cmdline"));
    try testing.expectEqual(@as(usize, 2), cmd.positional_args.items.len);
    try testing.expectEqualStrings("kernel", cmd.positional_args.items[0].name);
    try testing.expectEqualStrings("initrd", cmd.positional_args.items[1].name);
}
