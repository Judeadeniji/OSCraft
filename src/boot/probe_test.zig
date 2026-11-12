//! OSCraft — Boot Engine: Live EFI & ESP Directory Scanner Tests
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT

const std = @import("std");
const probe = @import("probe.zig");

test "unit: detect orphaned directories given simulated esp and efibootmgr output" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const mock_esp_dirs = [_][]const u8{
        "BOOT",
        "ubuntu",
        "BlissOS",
        "systemd",
    };

    const mock_efibootmgr =
        "BootCurrent: 0001\n" ++
        "BootOrder: 0001,0000\n" ++
        "Boot0000* Windows Boot Manager\tHD(1,GPT,1111,0x800,0x100000)/File(\\EFI\\Microsoft\\Boot\\bootmgfw.efi)57494e444f575300\n" ++
        "Boot0001* ubuntu\tHD(1,GPT,1111,0x800,0x100000)/File(\\EFI\\ubuntu\\shimx64.efi)\n";

    const orphans = try probe.detectOrphansFromEspAndOutput(
        allocator,
        &mock_esp_dirs,
        mock_efibootmgr,
    );
    defer allocator.free(orphans);

    // BOOT and systemd are protected system folders.
    // ubuntu matches Boot0001.
    // BlissOS has no NVRAM entry -> must be detected as an orphan!
    try testing.expectEqual(@as(usize, 1), orphans.len);
    try testing.expectEqualStrings("BlissOS", orphans[0]);
}
