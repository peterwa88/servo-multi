// Simple synchronous HTTP server for serving test fixtures
// No complex async setup needed

use std::env;
use std::fs;
use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::thread;

fn main() {
    let port: u16 = env::args()
        .nth(1)
        .and_then(|s| s.parse::<u16>().ok())
        .unwrap_or(8888);

    let addr = format!("127.0.0.1:{}", port);
    println!("Starting HTTP server on port {}...", port);
    println!("Fixtures will be served from: http://127.0.0.1:{}/", port);
    println!("Available fixtures:");
    println!("  - http://127.0.0.1:{}/fixtures/basic-page.html", port);
    println!(
        "  - http://127.0.0.1:{}/fixtures/multilingual-test.html",
        port
    );
    println!(
        "  - http://127.0.0.1:{}/fixtures/navigation-test.html",
        port
    );
    println!();

    let listener = match TcpListener::bind(&addr) {
        Ok(l) => l,
        Err(e) => {
            eprintln!("Failed to bind to {}: {}", addr, e);
            std::process::exit(1);
        }
    };

    println!("✓ HTTP server listening on http://{}", addr);

    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                thread::spawn(move || {
                    if let Err(e) = handle_client(stream) {
                        eprintln!("Client error: {}", e);
                    }
                });
            }
            Err(e) => {
                eprintln!("Connection error: {}", e);
            }
        }
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

    // Parse request line
    let mut parts = request_line.split_whitespace();
    let method = parts.next().unwrap_or("");
    let path = parts.next().unwrap_or("/");

    // Only handle GET requests
    if method != "GET" {
        let response = b"HTTP/1.1 405 Method Not Allowed\r\n\r\n";
        stream.write_all(response)?;
        return Ok(());
    }

    // Resolve file path
    let mut file_path = format!("servo_src/fixtures/{}", path.trim_start_matches('/'));

    // Security: ensure we only serve from fixtures directory
    if !file_path.starts_with("servo_src/fixtures") {
        let response = b"HTTP/1.1 403 Forbidden\r\n\r\nAccess Denied";
        stream.write_all(response)?;
        return Ok(());
    }

    // Check if file exists
    if fs::metadata(&file_path).is_err() {
        file_path = format!(
            "servo_src/fixtures/{}.html",
            path.trim_start_matches('/').trim_end_matches('/')
        );
    }

    if fs::metadata(&file_path).is_err() {
        // Try index.html
        file_path = format!("{}/index.html", path.trim_start_matches('/'));
    }

    // Send file
    match fs::read_to_string(&file_path) {
        Ok(content) => {
            let status = "200 OK";
            let content_type = if file_path.ends_with(".html") {
                "text/html"
            } else if file_path.ends_with(".css") {
                "text/css"
            } else if file_path.ends_with(".js") {
                "application/javascript"
            } else {
                "text/plain"
            };

            let response = format!(
                "HTTP/1.1 {}\r\nContent-Type: {}\r\nContent-Length: {}\r\n\r\n{}",
                status,
                content_type,
                content.len(),
                content
            );
            stream.write_all(response.as_bytes())?;
        }
        Err(_e) => {
            let response = b"HTTP/1.1 404 Not Found\r\n\r\nFile not found";
            stream.write_all(response)?;
        }
    }

    stream.flush()
}
