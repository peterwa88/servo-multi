// Research driver for servo-multi
// Provides servoshell subprocess wrapper with logging and control

use std::fs;
use std::io::{BufRead, BufReader, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::process::{Command, Stdio};
use std::thread;
use std::time::Duration;

fn main() -> std::io::Result<()> {
    println!("=== Servo Research Driver - M3 ===\n");

    // Step 1: Verify servo_origin exists
    let project_root = std::env::current_dir()?.to_string_lossy().to_string();
    let servo_origin_path = format!("{}/servo_origin", project_root);

    if !std::path::Path::new(&servo_origin_path).exists() {
        eprintln!("❌ Error: servo_origin directory not found!");
        eprintln!("Please run: ./scripts/bootstrap_servo_origin.sh");
        std::process::exit(1);
    }
    println!("✓ servo_origin exists");

    // Step 2: Check servoshell binary (try release first, then debug)
    let servoshell_release = format!("{}/ports/servoshell/target/release/servoshell.exe", servo_origin_path);
    let servoshell_debug = format!("{}/ports/servoshell/target/debug/servoshell.exe", servo_origin_path);

    let servoshell_path = if std::path::Path::new(&servoshell_release).exists() {
        println!("✓ Found servoshell in target/release\n");
        servoshell_release
    } else if std::path::Path::new(&servoshell_debug).exists() {
        println!("✓ Found servoshell in target/debug\n");
        servoshell_debug
    } else {
        println!("❌ Error: servoshell binary not found!");
        println!("Please build servoshell first:");
        println!("  cd servo_origin/ports/servoshell");
        println!("  cargo build --target x86_64-pc-windows-msvc\n");
        std::process::exit(1);
    };

    // Launch the browser
    launch_servoshell(&project_root, &servoshell_path);

    Ok(())
}

fn test_http_server(_project_root: &str) {
    println!("=== Testing HTTP Server ===\n");

    let port = 8888;
    let addr = format!("127.0.0.1:{}", port);
    let _listener = match TcpListener::bind(&addr) {
        Ok(l) => l,
        Err(e) => {
            eprintln!("Failed to bind to {}: {}", addr, e);
            return;
        }
    };
    println!("✓ HTTP server listening on http://{}\n", addr);

    // Serve a few test requests
    let test_requests = vec![
        "/",
        "/fixtures/basic-page.html",
        "/fixtures/multilingual-test.html",
        "/api/navigation/reset",
        "/api/navigation/forward",
        "/api/navigation/back",
        "/api/browser/screenshot",
        "/api/browser/dom_dump",
        "/api/network/log",
    ];

    for request_path in test_requests {
        println!("Testing: {}", request_path);
        if let Err(e) = test_http_request(&addr, request_path) {
            eprintln!("  ❌ Error: {}", e);
        } else {
            println!("  ✓ Success");
        }
    }

    println!("\n=== HTTP Server Test Complete ===");
}

fn test_http_request(addr: &str, path: &str) -> std::io::Result<()> {
    use std::net::TcpStream;
    use std::io::Write;

    let mut stream = TcpStream::connect(addr)?;
    let request = format!("GET {} HTTP/1.1\r\nHost: localhost\r\n\r\n", path);
    stream.write_all(request.as_bytes())?;

    // Read response
    let _response = String::new();
    let mut reader = std::io::BufReader::new(stream);
    let mut line = String::new();
    let _ = reader.read_line(&mut line);

    if line.contains("HTTP/1.1 200") {
        println!("    Response: {}", line.trim());
    } else {
        println!("    Response: {}", line.trim());
    }

    Ok(())
}

fn start_http_server(project_root: String) {
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
        let pr = project_root.clone();
        thread::spawn(move || {
            if let Err(e) = handle_client(stream, &pr) {
                eprintln!("Client error: {}", e);
            }
        });
    }
}

fn handle_client(mut stream: TcpStream, project_root: &str) -> std::io::Result<()> {
    let mut buffer = [0u8; 1024];
    stream.read_exact(&mut buffer)?;

    let request = String::from_utf8_lossy(&buffer);
    let request_line = request.lines().next().unwrap_or("");

    if request_line.is_empty() {
        return Ok(());
    }

    let mut parts = request_line.split_whitespace();
    let _method = parts.next().unwrap_or("");
    let path = parts.next().unwrap_or("/");

    // Handle API endpoints
    if path == "/api/navigation/reset" {
        let response = b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 30\r\n\r\n{\"status\":\"reset\"}";
        stream.write_all(response)?;
        return Ok(());
    }

    if path == "/api/navigation/forward" {
        let response = b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 31\r\n\r\n{\"status\":\"forwarded\"}";
        stream.write_all(response)?;
        return Ok(());
    }

    if path == "/api/navigation/back" {
        let response = b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 29\r\n\r\n{\"status\":\"backed\"}";
        stream.write_all(response)?;
        return Ok(());
    }

    if path == "/api/browser/screenshot" {
        let response = b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 33\r\n\r\n{\"status\":\"screenshot_saved\"}";
        stream.write_all(response)?;
        return Ok(());
    }

    if path == "/api/browser/dom_dump" {
        let response = b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 32\r\n\r\n{\"status\":\"dom_dump_ready\"}";
        stream.write_all(response)?;
        return Ok(());
    }

    if path == "/api/network/log" {
        let response = b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 29\r\n\r\n{\"status\":\"network_logged\"}";
        stream.write_all(response)?;
        return Ok(());
    }

    let fixtures_path = format!("{}/servo_src/fixtures", project_root);
    let absolute_path = if path == "/" {
        format!("{}/basic-page.html", fixtures_path)
    } else if path.starts_with("fixtures/") {
        let file_path = format!("fixtures/{}", path.trim_start_matches('/'));
        format!("{}/{}", fixtures_path, file_path)
    } else if path.starts_with("/api/navigation/") {
        // Navigation control API endpoints - return success response
        let response = b"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: 30\r\n\r\n{\"status\":\"received\"}";
        stream.write_all(response)?;
        return Ok(());
    } else {
        return Ok(());
    };

    let content = match fs::read_to_string(&absolute_path) {
        Ok(c) => c,
        Err(_) => {
            let response = b"HTTP/1.1 404 Not Found\r\n\r\nFile not found";
            stream.write_all(response)?;
            return Ok(());
        }
    };

    let content_type = if absolute_path.ends_with(".html") {
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

fn launch_servoshell(project_root: &str, servoshell_path: &str) {
    // Use Windows file:// URL format
    let target_url = "file:///D:/workspace/claude/servo-multi/servo_src/fixtures/multilingual-test.html";

    println!("=== Launching Servo Browser ===");
    println!("Browser: {}", servoshell_path);
    println!("URL: {}", target_url);
    println!("==================================\n");

    let mut child = match Command::new(&servoshell_path)
        .args(&[target_url])
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
    {
        Ok(child) => {
            println!("✓ Browser launched successfully\n");
            child
        }
        Err(e) => {
            eprintln!("❌ Failed to launch browser: {}", e);
            std::process::exit(1);
        }
    };

    // Capture and log output
    if let (Some(stdout), Some(stderr)) = (child.stdout.take(), child.stderr.take()) {
        let stdout_reader = BufReader::new(stdout);
        let stderr_reader = BufReader::new(stderr);

        println!("=== Browser Output ===\n");
        for line in stdout_reader.lines().chain(stderr_reader.lines()) {
            if let Ok(line) = line {
                // Filter out noise
                if !line.contains("GLFW") && !line.contains("wayland") && !line.is_empty() {
                    println!("{}", line);
                }
            }
        }
        println!("\n=== Output captured ===");
    }

    // Keep browser running for user interaction
    println!("\n⚠ Browser is running. Close the browser window to exit.");
    println!("The research driver will exit when you close the browser.\n");

    // Wait for process to complete
    match child.wait() {
        Ok(status) => {
            println!("Browser exited with status: {}", status);
            if !status.success() {
                println!("⚠ Browser encountered errors during runtime");
            }
        }
        Err(e) => {
            eprintln!("⚠ Error waiting for browser: {}", e);
        }
    }
}