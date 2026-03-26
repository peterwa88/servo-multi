# Test Fixtures

## Purpose
Local HTML fixtures for smoke testing Servo-based browser functionality.

## Location
- **Pages:** `servo_src/fixtures/`
- **Served from:** `http://127.0.0.1:8888/`

## Current Fixtures

### 1. basic-page.html
Minimal HTML page with basic styling and content.

### 2. multilingual-test.html
Test page for Unicode support (Chinese and English text).

### 3. navigation-test.html
Test page for basic navigation features (links).

## Fixture URLs

| Fixture | URL |
|---------|-----|
| Basic page | http://127.0.0.1:8888/fixtures/basic-page.html |
| Multilingual | http://127.0.0.1:8888/fixtures/multilingual-test.html |
| Navigation | http://127.0.0.1:8888/fixtures/navigation-test.html |

## Creating New Fixtures

1. Create HTML file in `servo_src/fixtures/`
2. Add to fixture list above
3. Update research_driver if needed

## Validation
Each fixture should be:
- Valid HTML5
- Responsive (works on different window sizes)
- Test basic rendering and input handling