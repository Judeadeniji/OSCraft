//! OSCraft — System Command Execution Engine
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");

const Io = std.Io;

pub const ExecutionMode = enum {
    dry_run,
    live,
};

pub const CommandInvocation = struct {
    args: []const []const u8,
};

pub const SystemExecutor = struct {
    allocator: std.mem.Allocator,
    io: Io,
    mode: ExecutionMode,
    history: std.ArrayList(CommandInvocation),

    pub fn init(allocator: std.mem.Allocator, io: Io, mode: ExecutionMode) SystemExecutor {
        return .{
            .allocator = allocator,
            .io = io,
            .mode = mode,
            .history = std.ArrayList(CommandInvocation).empty,
        };
    }

    pub fn deinit(self: *SystemExecutor) void {
        for (self.history.items) |cmd| {
            for (cmd.args) |arg| {
                self.allocator.free(arg);
            }
            self.allocator.free(cmd.args);
        }
        self.history.deinit(self.allocator);
    }

    /// Dispatches a command sequence according to the configured execution mode.
    /// In dry_run mode, the command is recorded in history and validated.
    /// In live mode, it executes and verifies the process exit code.
    pub fn dispatch(self: *SystemExecutor, args: []const []const u8) !void {
        if (args.len == 0) return error.EmptyCommand;

        // Record invocation
        var duped_args = try self.allocator.alloc([]const u8, args.len);
        errdefer self.allocator.free(duped_args);

        for (args, 0..) |arg, i| {
            duped_args[i] = try self.allocator.dupe(u8, arg);
        }

        try self.history.append(self.allocator, .{ .args = duped_args });

        if (self.mode == .dry_run) {
            return;
        }

        // Live execution via std.process.run in Zig 0.17
        const res = try std.process.run(self.allocator, self.io, .{
            .argv = args,
        });
        defer {
            self.allocator.free(res.stdout);
            self.allocator.free(res.stderr);
        }

        if (!res.term.success()) {
            return error.CommandFailed;
        }
    }

    /// Reloads the Linux kernel partition table for a block device (e.g. /dev/sda).
    pub fn reloadPartitionTable(self: *SystemExecutor, disk_path: []const u8) !void {
        const args = [_][]const u8{ "partprobe", disk_path };
        try self.dispatch(&args);
    }

    /// Adds a block device to a live mounted Btrfs filesystem pool.
    pub fn addBtrfsDevice(self: *SystemExecutor, device_path: []const u8, mount_point: []const u8) !void {
        const args = [_][]const u8{ "btrfs", "device", "add", "-f", device_path, mount_point };
        try self.dispatch(&args);
    }

    /// Removes a block device from a live mounted Btrfs filesystem pool.
    pub fn removeBtrfsDevice(self: *SystemExecutor, device_path: []const u8, mount_point: []const u8) !void {
        const args = [_][]const u8{ "btrfs", "device", "remove", device_path, mount_point };
        try self.dispatch(&args);
    }

    /// Executes the final CPU jump into the staged kexec kernel.
    pub fn executeKexecJump(self: *SystemExecutor) !void {
        const args = [_][]const u8{ "kexec", "-e" };
        try self.dispatch(&args);
    }
};
