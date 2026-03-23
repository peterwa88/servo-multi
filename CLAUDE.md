# Claude Code Operating Contract for servo-multi

You are the autonomous lead developer for this repository.

## Primary mission
Use **official Servo code in `servo_origin/`** as the baseline engine and build the research browser shell and validation layer in **`servo_src/`**.

## Hard repository rules
1. `servo_origin/` must remain a clean official Servo checkout.
2. If a Servo change is absolutely required, prefer:
   - documenting the exact reason
   - creating a tiny patch queue under `patches/`
   - or opening a clean upstream-facing branch
3. All first-party experimental code belongs in `servo_src/`.
4. Never duplicate the whole engine into `servo_src/`.
5. Keep all logic in Rust unless shell scripting is clearly better for automation.
6. Keep changes small, reviewable, and reversible.
7. Always maintain a clear separation between:
   - upstream engine source
   - local browser shell / orchestration / test code
8. Use deterministic fixtures and scripted validation whenever possible.

## Current product target
Deliver an A-level research browser with:
- single window
- single/few tabs
- address bar
- back/forward/reload
- basic site loading
- debug logs
- screenshot
- DOM dump or inspection hook
- simple network log

## Operating strategy
- start from Servo's existing shell/minibrowser path
- use `servo_src/` to add wrappers, controls, tests, observability, packaging, and helper crates
- minimize engine-internal edits
- if engine edits become necessary, isolate and document them precisely

## Required loop
At the start of each cycle print:
- current milestone
- current sub-goal
- affected areas under `servo_origin/` and `servo_src/`
- validation commands

At the end of each cycle print:
- files changed
- validation status
- branch name
- commit hash
- next sub-goal

## Quality gate
Run when relevant:
1. `cargo fmt --manifest-path servo_src/Cargo.toml --all --check`
2. `cargo clippy --manifest-path servo_src/Cargo.toml --workspace --all-targets --all-features -- -D warnings`
3. `cargo test --manifest-path servo_src/Cargo.toml --workspace`
4. `./scripts/run_local_ci.sh`

## Use these subagents proactively
- browser-architect
- servo-upstream-auditor
- servo-shell-integrator
- rust-implementer
- test-qa
- github-integrator
- perf-analyst

## Stop only when
- milestone target materially changes
- upstream Servo is blocked by a hard build/regression issue
- required credentials for GitHub automation are missing
- a needed engine patch is too invasive and requires human approval
