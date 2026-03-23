# Architecture

## Dual-tree principle
- `servo_origin/`: upstream engine and official browser shell code
- `servo_src/`: local research browser surface and validation stack

## Expected future `servo_src/` layout
- `tools/research_driver/`: launcher / orchestration binary
- `crates/browser_controls/`: address bar, navigation actions, command dispatch
- `crates/browser_observability/`: screenshot, DOM dump, network log helpers
- `tests/smoke/`: deterministic fixture-driven validation
