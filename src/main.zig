//! OSCraft — Application Entry Point
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const zli = @import("zli");
const OSCraft = @import("OSCraft");

const Io = std.Io;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var wbuf: [1024]u8 = undefined;
    var stdout_writer = Io.File.Writer.init(.stdout(), io, &wbuf);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    var rbuf: [1024]u8 = undefined;
    var stdin_reader = Io.File.Reader.init(.stdin(), io, &rbuf);
    const stdin = &stdin_reader.interface;

    const init_options = zli.InitOptions{
        .allocator = init.gpa,
        .io = io,
        .writer = stdout,
        .reader = stdin,
    };

    const root = try OSCraft.cli.root.initCli(init_options);

    var args_iter = init.minimal.args.iterate();
    root.runAndExit(&args_iter, .{});
}

test {
    _ = OSCraft;
}
