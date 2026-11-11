//! OSCraft — Application Entry Point
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const Io = std.Io;
const OSCraft = @import("OSCraft");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    try OSCraft.printBanner(stdout_writer);
    try stdout_writer.flush();
}

test {
    _ = OSCraft;
}
