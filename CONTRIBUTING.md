# Contributing to OSCraft

Thank you for your interest in contributing to **OSCraft**! OSCraft is a native Linux systems utility designed for non-destructive partition planning, live disk management, UEFI boot entry hygiene, and instant kernel reboot via `kexec`.

## Code of Conduct

All contributors and maintainers are expected to follow our [Code of Conduct](CODE_OF_CONDUCT.md) to ensure an inclusive, respectful, and productive environment.

---

## Prerequisites

- **Zig Toolchain**: Zig 0.17.0+ (accessible as `zig` or `zig17` depending on your environment).
- **Linux Environment**: Kernel 5.15+ recommended for modern `kexec_file_load`, Btrfs, and UEFI sysfs interfaces (`/sys/firmware/efi/efivars`).
- **Formatting Tools**: Ensure your editor respects `zig fmt`.

---

## Development Workflow

### 1. Fork and Clone

```bash
git clone https://github.com/<your-username>/OSCraft.git
cd OSCraft
```

### 2. Running Tests

OSCraft places high emphasis on data safety and verification. Before submitting any changes, verify all test suites pass:

```bash
# Using Zig 0.17
zig build test
# or if installed as zig17
zig17 build test
```

### 3. Code Standards & Philosophy

- **Data Safety First**: OSCraft operates on low-level disk structures and kernel interfaces. All boundary checks, sector alignment calculations, and filesystem calls must be rigorously validated.
- **Explicit Allocations**: Respect Zig idiom regarding memory allocators. Avoid hidden allocations; pass allocators explicitly.
- **Idiomatic Error Sets**: Use descriptive Zig error unions rather than panicking or swallowing errors.
- **Code Formatting**: Format code using `zig fmt` prior to committing:
  ```bash
  zig fmt src/ build.zig
  ```

---

## Pull Request Guidelines

1. **Focused Scope**: Keep pull requests focused on a single feature, bug fix, or documentation update.
2. **Behavioral Tests**: Any new disk, filesystem, or UEFI feature must include corresponding unit and behavioral test coverage (e.g. companion `*_test.zig` files).
3. **Commit Messages**: Follow Conventional Commits format:
   - `feat(storage): ...`
   - `fix(uefi): ...`
   - `docs: ...`
   - `test: ...`
4. **Documentation**: Update [docs/BLUEPRINT.md](docs/BLUEPRINT.md) or module headers if changing architectural contracts or introducing new subsystems.
