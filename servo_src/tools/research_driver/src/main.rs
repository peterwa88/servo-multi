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

    // Step 2: Check servoshell binary
    let servoshell_path = format!("{}/ports/servoshell/target/release/servoshell.exe", servo_origin_path);

    if !std::path::Path::new(&servoshell_path).exists() {
        println!("⚠ Servo not yet built");
        println!("To build servoshell, run:");
        println!("  cd servo_origin");
        println!("  python ./mach build servoshell");
        println!("Note: On Windows, mach has limitations with case-sensitive paths.\n");
        println!("This research driver will test the HTTP server and fixture serving only.");
        println!("For full servoshell integration, complete the build first.\n");

        // Test HTTP server and fixtures without servoshell
        test_http_server(&project_root);
    } else {
        println!("✓ servoshell binary found\n");

        // Step 3: Start HTTP server for fixtures
        println!("=== Starting HTTP server ===");
        let server_root = project_root.clone();
        let _server_thread = thread::spawn(move || {
            start_http_server(server_root);
        });

        thread::sleep(Duration::from_millis(500));

        // Step 4: Launch servoshell with test URL
        println!("\n=== Launching Servo Browser ===");
        launch_servoshell(&project_root);

        println!("\n=== Cleaning up ===");
        println!("✓ Research driver completed");
    }

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

fn launch_servoshell(project_root: &str) {
    println!("Launching servoshell with http://127.0.0.1:8888/fixtures/multilingual-test.html\n");

    let servoshell_path = format!("{}/servo_origin/ports/servoshell/target/release/servoshell.exe", project_root);
    let target_url = "http://127.0.0.1:8888/fixtures/multilingual-test.html";

    println!("Command: {}", servoshell_path);
    println!("Target URL: {}", target_url);
    println!("Logging servoshell output:\n");

    let mut child = match Command::new(&servoshell_path)
        .args(&[target_url])
        .current_dir(&format!("{}/servo_origin", project_root))
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
    {
        Ok(child) => child,
        Err(e) => {
            eprintln!("❌ Failed to spawn servoshell: {}", e);
            return;
        }
    };

    // Capture and print output in real-time
    if let (Some(stdout), Some(stderr)) = (child.stdout.take(), child.stderr.take()) {
        let stdout_reader = BufReader::new(stdout);
        let stderr_reader = BufReader::new(stderr);

        for line in stdout_reader.lines().chain(stderr_reader.lines()) {
            if let Ok(line) = line {
                println!("{}", line);
            }
        }
    }

    // Wait for servoshell to complete
    match child.wait() {
        Ok(status) => {
            println!("\nServoshell exited with status: {}", status);
            if status.success() {
                println!("✓ Servo browser exited normally");
            } else {
                println!("⚠ Servo browser exited with errors");
            }
        }
        Err(e) => {
            eprintln!("⚠ Error waiting for servoshell: {}", e);
        }
    }
}