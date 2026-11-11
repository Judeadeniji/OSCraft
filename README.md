# OSCraft

> A modern Linux utility for live disk partitioning without reboot, UEFI boot hygiene, USB-less ISO booting, and instant OS switching via `kexec`.

* **Author:** [Oluwaferanmi Adeniji](https://github.com/Judeadeniji)
* **Date:** November 2026
* **License:** MIT

## Overview

OSCraft unifies low-level Linux kernel features (`kexec_file_load`, `partprobe`, Btrfs dynamic multi-device pooling, and UEFI NVRAM efivars) into a fast, native application built in **Zig 0.17** and **nanoui**.

## Documentation

* [Architecture & Engineering Blueprint](docs/BLUEPRINT.md)

## Development

Run unit and behavioral tests:

```bash
zig build test
```

Run the application:

```bash
zig build run
```
