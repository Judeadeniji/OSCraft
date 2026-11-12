//! OSCraft — Native GUI Application Entry Point
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const app = @import("ui/app.zig");

pub fn main(init: std.process.Init) !void {
    try app.run(init);
}
