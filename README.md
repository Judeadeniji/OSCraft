# OSCraft

> A modern Linux utility for live disk partitioning without reboot, UEFI boot hygiene, USB-less ISO booting, and instant OS switching via `kexec`.

[![CI](https://github.com/Judeadeniji/OSCraft/actions/workflows/ci.yml/badge.svg)](https://github.com/Judeadeniji/OSCraft/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Zig](https://img.shields.io/badge/Zig-0.17.0%2B-orange.svg)](https://ziglang.org/)

* **Author:** [Oluwaferanmi Adeniji](https://github.com/Judeadeniji)
* **Date:** November 2026
* **License:** [MIT](LICENSE)

## Overview

OSCraft unifies low-level Linux kernel features (`kexec_file_load`, `partprobe`, Btrfs dynamic multi-device pooling, and UEFI NVRAM efivars) into a fast, native application built in **Zig 0.17** and **nanoui**.

## Documentation

* [Architecture & Engineering Blueprint](docs/BLUEPRINT.md)
* [Agent Directives & Rules](AGENTS.md)
* [Contributing Guidelines](CONTRIBUTING.md)
* [Code of Conduct](CODE_OF_CONDUCT.md)
* [Security Policy](SECURITY.md)

## Development

Requires **Zig 0.17.0+** (run as `zig17` or `zig` depending on your environment).

Run unit and behavioral tests:

```bash
zig17 build test
# or
zig build test
```

Run the application:

```bash
zig17 build run
# or
zig build run
```
