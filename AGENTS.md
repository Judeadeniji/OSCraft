# AGENTS.md — Agent Guidelines & Repository Directives

Welcome to **OSCraft**. This document contains mandatory rules, architectural guidelines, and workflow conventions for AI coding agents and autonomous contributors working in this repository.

<!-- intent-skills:start -->
## Skill Loading

Use the repository’s installed Intent. If it is unavailable, report the missing dependency instead of downloading a replacement.
Before editing files for a substantial task:
- Run `bunx --no-install --package @tanstack/intent intent list` from the workspace root to see available local skills.
- If a listed skill matches the task, run `bunx --no-install --package @tanstack/intent intent load <package>#<skill>` before changing files.
- Use the loaded `SKILL.md` guidance while making the change.
- Monorepos: when working across packages, run the skill check from the workspace root and prefer the local skill for the package being changed.
- Multiple matches: prefer the most specific local skill for the package or concern you are changing; load additional skills only when the task spans multiple packages or concerns.
<!-- intent-skills:end -->

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

### 🚫 ABSOLUTE BAN ON `useEffect`
- **`useEffect` is strictly banned across this repository.**
- Never use `useEffect` in React components, pages, or custom hooks.
- **Rule**: Do not use effects for data fetching, state synchronization, or derived values.
  - **Data loading**: Use **TanStack Query / React Query** (`useQuery`), TanStack Router route `loader` functions, or event-driven IPC triggers.
  - **User events & mutations**: Execute side effects directly inside event handlers (`onClick`, `onChange`, `onSubmit`) or mutations (`useMutation`).
  - **Derived state**: Compute values directly during render.
  - **Subscriptions / External stores**: Use `useSyncExternalStore`.

```tsx
// ❌ WRONG (BANNED):
function DiskList() {
  const [disks, setDisks] = useState([]);
  useEffect(() => {
    fetchDisks().then(setDisks);
  }, []);
  return <div>{disks.map(...)}</div>;
}

// ✅ CORRECT (React Query / TanStack Query):
function DiskList() {
  const { data: disks = [] } = useQuery({
    queryKey: ['disks'],
    queryFn: fetchDisks,
  });
  return <div>{disks.map(...)}</div>;
}

// ✅ ALSO CORRECT (TanStack Router loader):
export const Route = createFileRoute('/')({
  loader: async () => fetchDisks(),
  component: DiskList,
});

function DiskList() {
  const disks = Route.useLoaderData();
  return <div>{disks.map(...)}</div>;
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
- Do not add `Co-authored-by` trailers. The `.githooks/commit-msg` hook strips them. To enable hooks after clone: `git config core.hooksPath .githooks`

---

## Product blueprint

Read [`docs/blueprint.md`](docs/blueprint.md) for product scope, MVP features, draw/privacy model, site map, SEO, monetization, and growth. Prefer that file over the original PDF. When the blueprint and the shipped UI disagree, follow the repo (TanStack Start, Giftly night-village / paper, Santa's Secret draw) unless the task is explicitly to change product direction.

---

## Styling: Tailwind CSS v4

Always write Tailwind CSS v4 (installed: `tailwindcss` / `@tailwindcss/vite` v4). Do not use v3 syntax or install a v3 toolchain. Tailwind is imported from CSS with `@import "tailwindcss"` in [`src/styles.css`](src/styles.css); never use `@tailwind` directives.

- CSS-first config. No `tailwind.config.js/ts` and no `@config` unless explicitly required. Design tokens, fonts, breakpoints, keyframes, and animations belong in `@theme` / `@theme inline` in `src/styles.css`. Use `:root` only for plain CSS variables that should not generate Tailwind utilities/variants.
- Register plugins with `@plugin '...'` and project-level primitives with `@utility` / `@custom-variant` in CSS. Do not create utilities with `@layer utilities`; use `@utility` so variants such as `hover:` and `lg:` work.
- Use the v4 utility semantics and names:
  - Opacity modifiers use slash syntax: `bg-sky/40`, `text-ink/70`; `bg-opacity-*`, `text-opacity-*`, `border-opacity-*`, `ring-opacity-*`, `divide-opacity-*`, and `placeholder-opacity-*` are removed.
  - Migrating v3 `outline-none` → use `outline-hidden` in v4 (v4's `outline-none` actually sets `outline-style: none`). `outline-<number>` implies `solid`; no need for `outline outline-2`.
  - Default `ring` width is 1px (not 3px) and `ring`/`border` default to `currentColor`, so set color and width explicitly: `ring-2 ring-berry/40`, `border border-border`.
  - Renames: `shadow-sm`→`shadow-xs`, `shadow`→`shadow-sm`, `drop-shadow-sm`→`drop-shadow-xs`, `drop-shadow`→`drop-shadow-sm`, `blur-sm`→`blur-xs`, `blur`→`blur-sm`, `backdrop-blur-sm`→`backdrop-blur-xs`, `rounded-sm`→`rounded-xs`, `rounded`→`rounded-sm`, `flex-shrink-*`→`shrink-*`, `flex-grow-*`→`grow-*`, `overflow-ellipsis`→`text-ellipsis`, `decoration-slice`/`decoration-clone`→`box-decoration-slice`/`box-decoration-clone`.
  - Important modifier goes at the end: `bg-berry!`, `hover:bg-berry/80!` (leading `!` is deprecated).
  - Use `size-*` for square dimensions and `gap-*` for flex/grid spacing; the spacing scale is dynamic (`mt-17`, `w-29`).
  - Arbitrary CSS variables use parens: `bg-(--brand)` (not `bg-[--brand]`). Gradients are `bg-linear-*` / `bg-radial-*` / `bg-conic-*` (not `bg-gradient-*`); gradient stops persist across variants.
  - Stacked variants apply left-to-right: `*:first:pt-0`, not `first:*:pt-0`. Reset transforms with `scale-none` / `rotate-none` / `translate-none`, not `transform-none`.
  - `hover:` only applies on devices that support hover. Treat hover as enhancement; use `active:`/`focus-visible:` for touch-critical behavior.
  - Class names must appear as complete static strings; Tailwind scans source text and will not detect concatenated fragments. Map dynamic values to full class strings. Use `@source` for unusual source locations and `@source inline()` only for real safelisting needs.
- Prefer existing tokens/utilities already defined in `src/styles.css` over hardcoded hex values. Add new tokens to `@theme inline` and reference the `:root` variable rather than duplicating colors.

---

## Git commits

Do not add `Co-authored-by` trailers. The `.githooks/commit-msg` hook strips them. To enable hooks after clone: `git config core.hooksPath .githooks`
