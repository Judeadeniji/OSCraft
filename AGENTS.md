# AGENTS.md — Agent Guidelines & Repository Directives

Welcome to **OSCraft**. This document contains mandatory rules, architectural guidelines, and workflow conventions for AI coding agents and autonomous contributors working in this repository.

---

## 1. Toolchain & Environment

- **Zig Version**: This project strictly targets **Zig 0.17.0+**.
- **Executable Path**: The Zig 0.17 binary on this environment is located at `~/.local/bin/zig17` (or invoked as `zig17`). Do not use system `zig` if it points to an older version (e.g. Zig 0.15).
- **Test Command**:
  ```bash
  ~/.local/bin/zig17 build test
  # or
  zig17 build test
  ```
- **Build / Run Command**:
  ```bash
  ~/.local/bin/zig17 build run
  ```

---

## 2. Strict Coding Directives

### 🚫 ABSOLUTE BAN ON INLINE IMPORTS
- **Inline `@import(...)` is strictly banned across this repository.**
- Never use `@import(...)` inside function bodies, method signatures, `test` blocks, or local expressions.
- **Rule**: Every single `@import` statement MUST be declared as a `const` at the top level of the file before any logic or functions.

```zig
// ❌ WRONG (BANNED):
test "example" {
    const helper = @import("helper.zig");
    _ = helper;
}

// ✅ CORRECT:
const std = @import("std");
const helper = @import("helper.zig");

test "example" {
    _ = helper;
}
```

### Module Header Standards
Every new or modified Zig source file in `src/` must retain or include the canonical module header:

```zig
//! OSCraft — <Module Title>
//!
//! Author:  Oluwaferanmi Adeniji <https://github.com/Judeadeniji>
//! Date:    November 2026
//! License: MIT
```

### Data Safety & Kernel Guardrails
- OSCraft operates on live disks, partition tables (GPT/MBR), Btrfs volumes, and Linux kernel interfaces (`kexec_file_load`, UEFI NVRAM).
- Never write destructive commands without verification, alignment validation, and safety assertions.
- Separate command generation/topology calculation from actual OS execution so dry-run simulations can be thoroughly tested.

### Memory & Idioms
- Always pass `std.mem.Allocator` explicitly when an operation allocates.
- Use explicit error unions (`error{...}!T`) over panics.
- Clean up resources with `defer` or `errdefer`.

---

## 3. Testing & Verification

- Every domain module (e.g., `src/storage/disk.zig`) must have companion tests (e.g., `src/storage/disk_test.zig`).
- Register all tests in `src/root.zig` via top-level imports referenced in the `test` block.
- Always run `zig17 build test` to verify your changes compile and pass cleanly before committing.
- Run `zig17 fmt` to maintain consistent formatting.

---

## 4. Git & Commit Guidelines

- Follow Conventional Commits:
  - `feat(<subsystem>): ...`
  - `fix(<subsystem>): ...`
  - `refactor(<subsystem>): ...`
  - `test(<subsystem>): ...`
  - `docs: ...`
  - `chore: ...`
- Do not introduce unrelated file changes.
