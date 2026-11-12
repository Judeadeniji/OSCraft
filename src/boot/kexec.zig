//! OSCraft — Boot Engine: Zero-Reboot kexec Live Switching
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");

pub const DistroFlavor = enum {
    ubuntu_casper,
    arch_iso,
    fedora_dracut,
    generic,

    pub fn defaultCmdline(self: DistroFlavor, allocator: std.mem.Allocator, iso_path: []const u8) ![]const u8 {
        return switch (self) {
            .ubuntu_casper => try std.fmt.allocPrint(
                allocator,
                "boot=casper iso-scan/filename={s} toram quiet splash",
                .{iso_path},
            ),
            .arch_iso => try std.fmt.allocPrint(
                allocator,
                "img_loop={s} copytoram=y quiet",
                .{iso_path},
            ),
            .fedora_dracut => try std.fmt.allocPrint(
                allocator,
                "root=live:{s} rd.live.image rd.live.ram quiet",
                .{iso_path},
            ),
            .generic => try std.fmt.allocPrint(
                allocator,
                "findiso={s} toram quiet",
                .{iso_path},
            ),
        };
    }
};

pub const KexecStagePlan = struct {
    kernel_path: []const u8,
    initrd_path: []const u8,
    cmdline: []const u8,

    /// Validates safety invariants of the plan before invocation.
    pub fn validate(self: KexecStagePlan) !void {
        if (self.kernel_path.len == 0) return error.EmptyKernelPath;
        if (self.initrd_path.len == 0) return error.EmptyInitrdPath;
        if (self.cmdline.len == 0) return error.EmptyCommandLine;

        // Safety assertion: Live/RAM boot requires memory-backing flag to prevent kernel panic
        const has_live_indicator = (std.mem.indexOf(u8, self.cmdline, "toram") != null or
            std.mem.indexOf(u8, self.cmdline, "copytoram") != null or
            std.mem.indexOf(u8, self.cmdline, "rd.live.ram") != null or
            std.mem.indexOf(u8, self.cmdline, "root=") != null);

        if (!has_live_indicator) {
            return error.MissingLiveRamBootParameter;
        }
    }

    /// Constructs argument list for `kexec -l <kernel> --initrd=<initrd> --command-line="<cmdline>"`
    pub fn buildLoadArgs(self: KexecStagePlan, allocator: std.mem.Allocator) ![]const []const u8 {
        try self.validate();

        const append_flag = try std.fmt.allocPrint(allocator, "--command-line={s}", .{self.cmdline});
        errdefer allocator.free(append_flag);

        const initrd_flag = try std.fmt.allocPrint(allocator, "--initrd={s}", .{self.initrd_path});
        errdefer allocator.free(initrd_flag);

        return allocator.dupe([]const u8, &.{
            "kexec", "-l", self.kernel_path, initrd_flag, append_flag,
        });
    }

    /// Constructs argument list for executing the loaded kernel: `kexec -e`
    pub fn buildExecuteArgs(allocator: std.mem.Allocator) ![]const []const u8 {
        return allocator.dupe([]const u8, &.{
            "kexec", "-e",
        });
    }

    /// Constructs argument list for unloading any staged kernel: `kexec -u`
    pub fn buildUnloadArgs(allocator: std.mem.Allocator) ![]const []const u8 {
        return allocator.dupe([]const u8, &.{
            "kexec", "-u",
        });
    }
};
