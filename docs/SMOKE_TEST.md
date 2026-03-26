# Smoke Test Guide

## Quick Start

1. **Build Servo** (if not already built):
   ```bash
   cd servo_origin
   ./mach build
   ```

2. **Start fixture server** (in one terminal):
   ```bash
   cargo run --bin simple_server -- 8888
   ```

3. **Run smoke tests** (in another terminal):
   ```bash
   cargo run --bin research_driver
   ```

## Fixtures

| URL | Description |
|-----|-------------|
| http://127.0.0.1:8888/fixtures/basic-page.html | Basic HTML with styling |
| http://127.0.0.1:8888/fixtures/multilingual-test.html | Chinese and English text |
| http://127.0.0.1:8888/fixtures/navigation-test.html | Links for testing navigation |

## Validation Checklist

- [ ] Servo shell launches without errors
- [ ] Headless mode works (if applicable)
- [ ] Basic page renders correctly
- [ ] Multilingual text displays (Chinese and English)
- [ ] Navigation links work (if implemented)

## Troubleshooting

### Servo shell not found
Ensure Servo is built:
```bash
cd servo_origin && ./mach build
```

### Port already in use
Use a different port:
```bash
cargo run --bin simple_server -- 9999
```

### Build errors
Check Servo's official build instructions at https://book.servo.org/