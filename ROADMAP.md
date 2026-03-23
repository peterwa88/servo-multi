# ROADMAP

## M0 - Bootstrap dual-tree workflow
- initialize Claude Code control files
- document `servo_origin/` vs `servo_src/`
- add scripts to clone/pin/sync official Servo
- add CI, hooks, issue templates
- define acceptance criteria

Exit:
- the dual-tree workflow is documented
- `scripts/bootstrap_servo_origin.sh` works
- first autonomous loop can run safely

## M1 - Upstream baseline audit
- clone official Servo into `servo_origin/`
- record exact upstream pin
- identify the smallest runnable shell path
- document where address bar / shell CLI / logging hooks live upstream
- establish fixture strategy

Exit:
- upstream pin recorded
- build path documented
- local validation plan written

## M2 - Research shell wrapper in `servo_src/`
- create workspace for wrappers, launchers, fixture helpers, smoke tests
- add app launcher scripts
- add local fixture pages and smoke harness
- prove `servo_src/` can drive a baseline browser run

Exit:
- local fixtures exist
- wrapper/build/test entrypoints exist
- baseline app run is scripted

## M3 - A-level controls
- address bar
- back/forward/reload
- basic error handling
- deterministic navigation tests

Exit:
- navigation controls are implemented and testable

## M4 - Research observability
- screenshot
- DOM dump
- simple network logging
- launch/debug logs

Exit:
- all three observability surfaces work on a fixture page

## M5 - Packaging and continuous dev loop
- release workflow
- issue-driven automation
- regression gating
- performance target template

Exit:
- user can test a packaged alpha
- future loops can be triggered by GitHub issue text
