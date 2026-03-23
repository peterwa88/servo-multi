# servo-multi

Autonomous multi-agent research browser project based on **official Servo source**.

Repository target: `https://github.com/peterwa88/servo-multi.git`

## Repository contract
- `servo_origin/`: pristine official Servo source checkout
- `servo_src/`: your own browser shell, tests, wrappers, fixtures, and experimental control code
- do **not** directly redesign Servo from scratch
- do **not** treat `servo_src/` as a forked copy of the engine
- prefer composition, wrapper crates, scripts, tests, and minimal patch queues

## Goal for the current phase
Build an **A-level research MVP browser**:
- single window
- single tab or very few tabs
- address bar
- back / forward / reload
- open basic websites
- debug logs
- screenshot
- DOM inspection / dump
- simple network log

## Why this layout
This keeps upstream Servo auditable and updateable while isolating your research shell work in `servo_src/`.
