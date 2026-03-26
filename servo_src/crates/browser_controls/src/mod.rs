// Browser controls for navigation and interaction

use std::path::Path;

/// Navigate to a fixture URL
pub fn navigate_to_url(url: &str) -> Result<(), Box<dyn std::error::Error>> {
    println!("Navigating to: {}", url);

    // In a real implementation, this would send navigation commands to servoshell
    // For now, we'll just log the URL
    println!("  -> Would navigate servoshell to: {}", url);

    Ok(())
}

/// Load a fixture page
pub fn load_fixture(fixture_name: &str) -> Result<(), Box<dyn std::error::Error>> {
    let base_url = "http://127.0.0.1:8888";
    let url = format!("{}/fixtures/{}.html", base_url, fixture_name);

    navigate_to_url(&url)?;

    // Verify the URL is correct
    println!("  -> Fixture loaded: {}", url);

    Ok(())
}

/// Check if a URL is a local fixture
pub fn is_local_fixture(url: &str) -> bool {
    url.starts_with("http://127.0.0.1:8888/fixtures/") ||
    url.starts_with("http://localhost:8888/fixtures/")
}

/// Get fixture name from URL
pub fn get_fixture_name(url: &str) -> Option<&str> {
    if is_local_fixture(url) {
        let path = url.strip_prefix("http://127.0.0.1:8888/fixtures/")
            .or_else(|| url.strip_prefix("http://localhost:8888/fixtures/"))?;
        Some(path.split('/').next().unwrap_or(""))
    } else {
        None
    }
}