# Servo Baseline Path Documentation

## Upstream Pin
**Commit:** `ca898ea99ce5f2c8e7403e0750ff64fc59a6b634`
**Repository:** https://github.com/servo/servo.git
**Branch:** main

## Baseline Shell Entrypoint

### Binary
- **Path:** `servo_origin/ports/servoshell/target/release/servoshell.exe` (after build)
- **Source:** `servo_origin/ports/servoshell/main.rs`

### Main Entry Point
- **Function:** `desktop::cli::main()`
- **Location:** `servo_origin/ports/servoshell/desktop/cli.rs`

### Build Command
```bash
cd servo_origin
./mach build
```

### Minimal Launch Arguments
The servoshell accepts various command-line arguments. Basic usage:
```bash
./ports/servoshell/target/release/servoshell.exe --help
```

## Shell Components

### Core Files
- `lib.rs` - Main library entry, defines platform modules and crypto init
- `desktop/cli.rs` - CLI argument parsing and main event loop
- `desktop/app.rs` - Application state and window management
- `desktop/event_loop.rs` - Event loop implementation
- `prefs.rs` - Command-line argument parsing for preferences

### Platform Support
- **Windows:** `ports/servoshell/desktop/app.rs` (egui-based)
- **Desktop:** Standard X11/Wayland/MacOS window management

## Key Observations

1. **Headless mode:** Available via `--headless` flag
2. **Logging:** `tracing` filter via `--tracing-filter` argument
3. **Window management:** Egui-based on Windows
4. **Dependencies:** Requires full Servo engine build (not just shell)

## Build Artifacts

After `./mach build`:
- Binary: `ports/servoshell/target/release/servoshell.exe`
- Target directory: `ports/servoshell/target/release/`

## Testing Strategy

1. Use servoshell as a subprocess from `servo_src/tools/research_driver`
2. Capture stdout/stderr for logging
3. Verify basic page load capability
4. Use `--headless` for CI testing

## Dependencies

### Required for Build
- Rust toolchain (via rustup)
- Python + uv (for mach)
- Visual Studio 2022 with C++ tools
- Windows 10/11 SDK (>= 10.0.19041.0)
- GStreamer (for media features)
- LLVM

### Required for Runtime
- Same as build-time (runtime uses installed toolchain)