# Implementation Guide for servo-multi

## Repository
Target repository:
`https://github.com/peterwa88/servo-multi.git`

## Operating model
This repo is the **multi-agent / automation-heavy** variant.

- `servo_origin/` = official Servo checkout
- `servo_src/` = your own browser, tooling, tests, fixtures, packaging
- use subagents and GitHub issue-driven loops
- keep `servo_origin/` clean whenever possible

## First-time setup
1. Create or clone the repository:
   ```bash
   git clone git@github.com:peterwa88/servo-multi.git
   cd servo-multi
   ```

2. Copy this starter kit into the repo root and commit it.

3. Bootstrap official Servo:
   ```bash
   ./scripts/bootstrap_servo_origin.sh
   ```

4. Add your exact upstream commit to `SERVO_UPSTREAM_PIN.txt` after deciding the baseline.

5. Install Servo build dependencies following official Servo docs, then test upstream bootstrap/build from inside `servo_origin/`.

6. Configure Claude GitHub automation:
   - install the Claude GitHub app
   - add `ANTHROPIC_API_KEY` as a repository secret
   - enable GitHub Actions

## How Claude should work in this repo
- inspect `servo_origin/`
- create wrappers/tests/fixtures in `servo_src/`
- only patch `servo_origin/` when clearly justified
- document every patch point

## First development objective
Do not jump straight into broad UI work.

First:
- audit the official shell path
- document CLI, logging, and shell entrypoints
- create deterministic local fixtures
- create a smoke harness in `servo_src/`
