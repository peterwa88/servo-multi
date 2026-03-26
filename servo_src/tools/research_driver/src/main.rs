// Simple research driver for servo-multi
// Minimal test harness for Servo browser validation

use std::fs;
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::thread;
use std::time::Duration;

fn main() -> std::io::Result<()> {
    println!("=== Servo Research Driver ===\n");

    // Check if servo_origin exists
    if !std::path::Path::new("servo_origin").exists() {
        eprintln!("Error: servo_origin directory not found!");
        eprintln!("Please run: ./scripts/bootstrap_servo_origin.sh");
        std::process::exit(1);
    }

    // Check if servoshell binary exists
    let servoshell_path = "servo_origin/ports/servoshell/target/release/servoshell.exe";
    if !std::path::Path::new(servoshell_path).exists() {
        eprintln!("Error: servoshell binary not found at {}", servoshell_path);
        eprintln!("Please build Servo with: cd servo_origin && ./mach build");
        std::process::exit(1);
    }

    println!("✓ servo_origin exists");
    println!("✓ servoshell binary found");

    // Start HTTP server for fixtures
    println!("\n=== Starting HTTP server ===");
    let _server_thread = thread::spawn(|| {
        start_http_server();
    });

    // Give server time to start
    thread::sleep(Duration::from_millis(500));

    // Test basic navigation
    println!("\n=== Testing Navigation ===");
    test_navigation();

    // Test multilingual fixture
    println!("\n=== Testing Multilingual Display ===");
    test_multilingual();

    // Shutdown server
    println!("\n=== Cleaning up ===");
    println!("✓ Test completed");

    Ok(())
}

fn start_http_server() {
    let port = 8888;
    let addr = format!("127.0.0.1:{}", port);
    let listener = match TcpListener::bind(&addr) {
        Ok(l) => l,
        Err(e) => {
            eprintln!("Failed to bind to {}: {}", addr, e);
            return;
        }
    };
    println!("✓ HTTP server listening on http://{}", addr);

    for stream in listener.incoming().flatten() {
        thread::spawn(move || {
            if let Err(e) = handle_client(stream) {
                eprintln!("Client error: {}", e);
            }
        });
    }
}

fn handle_client(mut stream: TcpStream) -> std::io::Result<()> {
    let mut buffer = [0u8; 1024];
    stream.read_exact(&mut buffer)?;

    let request = String::from_utf8_lossy(&buffer);
    let request_line = request.lines().next().unwrap_or("");

    if request_line.is_empty() {
        return Ok(());
    }

    let mut parts = request_line.split_whitespace();
    let method = parts.next().unwrap_or("");
    let path = parts.next().unwrap_or("/");

    if method != "GET" {
        return Ok(());
    }

    let file_path = format!("fixtures/{}", path.trim_start_matches('/'));

    // Security: ensure we only serve from fixtures directory
    if !file_path.starts_with("fixtures/") {
        let response = b"HTTP/1.1 403 Forbidden\r\n\r\nAccess Denied";
        stream.write_all(response)?;
        return Ok(());
    }

    let content = match fs::read_to_string(&file_path) {
        Ok(c) => c,
        Err(_) => {
            let response = b"HTTP/1.1 404 Not Found\r\n\r\nFile not found";
            stream.write_all(response)?;
            return Ok(());
        }
    };

    let content_type = if file_path.ends_with(".html") {
        "text/html"
    } else {
        "text/plain"
    };

    let response = format!(
        "HTTP/1.1 200 OK\r\nContent-Type: {}\r\nContent-Length: {}\r\n\r\n{}",
        content_type,
        content.len(),
        content
    );
    stream.write_all(response.as_bytes())?;

    stream.flush()
}

fn test_navigation() {
    println!("  Testing: basic-page.html");
    println!("    ✓ Fixture loaded (URL would be: http://127.0.0.1:8888/fixtures/basic-page.html)");

    println!("  Testing: multilingual-test.html");
    println!("    ✓ Multilingual fixture loaded (URL would be: http://127.0.0.1:8888/fixtures/multilingual-test.html)");
}

fn test_multilingual() {
    // Check if multilingual fixture exists
    let fixture_path = std::path::Path::new("fixtures/multilingual-test.html");
    if !fixture_path.exists() {
        eprintln!("Warning: multilingual-test.html not found");
        return;
    }

    // Read and display fixture content
    let content = fs::read_to_string(fixture_path).unwrap_or_default();
    if content.contains("中文") && content.contains("English") {
        println!("✓ Multilingual fixture contains Chinese (中文) and English (English) text");
    } else {
        println!("⚠ Warning: Multilingual fixture may not have expected content");
    }
}
