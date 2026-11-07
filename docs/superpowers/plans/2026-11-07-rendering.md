# Rendering comparison implementation plan

Goal: reduce monitor flicker in two independently usable branches.
Architecture: buffer cursor movement, complete row content, and suffix erasure;
write one update per frame. Add previous-viewport state only on the diff branch.
Tech stack: Julia 1.10+ and existing ANSI/Term viewport handling.
Spec: docs/superpowers/specs/2026-11-07-rendering-design.md

## Constraints and review focus
Keep public keywords and cleanup behavior. Cover shorter rows, fewer rows, empty
frames, identical frames, styled/Unicode content, resize invalidation, and output
routing through the supplied IO. No dependency or test-environment migration.

## Task 1: buffered overwrite (fix/buffered-overwrite)
- [x] Add failing tests in test/render_update_tests.jl for frame_update(rendered)
  and monitor integration: final screen, no erase before replacement, one write.
- [x] Implement frame_update in src/TerminalSystemMonitor.jl and call it from main.
- [x] Run focused tests then julia --project -e 'using Pkg; Pkg.test()'.
- [x] Review diff, document comparison and commit.

## Task 2: line differences (fix/line-diff)
- [ ] Start again from main and carry shared design and test harness.
- [ ] Add failing tests for frame_update(rendered, previous; redraw=false):
  unchanged rows emit nothing, changed rows replace, removed rows disappear,
  resizing redraws all current rows.
- [ ] Implement helper and per-monitor previous viewport/size state.
- [ ] Run focused tests and full Pkg.test(), review diff, document and commit.

Execution: sequentially in the requested branches in the existing checkout.
The user explicitly requested implementation of both alternatives; no additional
approach selection or plan approval is needed.

Task 1: focused RED (missing helper) -> GREEN 15/15; full Pkg.test() 198/198.
Independent review: no actionable findings. JuliaFormatter unavailable; matched
local formatting and git diff --check passed.
