# Rust CE MCP Server Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Rust MCP server that replaces the Python `mcp_cheatengine.py` — same 43 tools, same pipe protocol, with proper async timeouts.

**Architecture:** Single Rust binary using `rmcp` (MCP SDK) + `tokio` (async runtime). Communicates with CE Lua bridge via Windows named pipe (`\\.\pipe\CE_MCP_Bridge_v99`). Stdio transport for Claude Code.

**Tech Stack:** Rust, rmcp 0.16+, tokio, serde_json, schemars

---

### Task 1: Project scaffold and pipe client

**Files:**
- Create: `Cargo.toml`
- Create: `src/main.rs`
- Create: `src/pipe.rs`

- [ ] **Step 1: Create GitHub repo and init project**

```bash
gh repo create tantk/cheatengine-mcp-rs --public --description "Rust MCP server for Cheat Engine"
mkdir C:\dev\cheatengine-mcp-rs && cd C:\dev\cheatengine-mcp-rs
cargo init --name ce-mcp-rs
```

- [ ] **Step 2: Write Cargo.toml**

```toml
[package]
name = "ce-mcp-rs"
version = "0.1.0"
edition = "2021"
description = "Rust MCP server for Cheat Engine — async named pipe with proper timeouts"

[dependencies]
rmcp = { version = "0.16", features = ["server", "transport-io", "macros"] }
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
schemars = "1"
anyhow = "1"
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
```

- [ ] **Step 3: Write the pipe client (`src/pipe.rs`)**

```rust
use anyhow::{anyhow, Result};
use serde_json::Value;
use std::time::Duration;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::windows::named_pipe::ClientOptions;
use tokio::time::timeout;

const DEFAULT_PIPE_NAME: &str = r"\\.\pipe\CE_MCP_Bridge_v99";
const DEFAULT_TIMEOUT: Duration = Duration::from_secs(30);

pub struct PipeClient {
    pipe_name: String,
    timeout: Duration,
}

impl PipeClient {
    pub fn new() -> Self {
        let pipe_name = std::env::var("CE_PIPE_NAME")
            .unwrap_or_else(|_| DEFAULT_PIPE_NAME.to_string());
        let timeout_secs: u64 = std::env::var("CE_PIPE_TIMEOUT")
            .ok()
            .and_then(|s| s.parse().ok())
            .unwrap_or(30);
        Self {
            pipe_name,
            timeout: Duration::from_secs(timeout_secs),
        }
    }

    pub async fn send_command(&self, method: &str, params: Value) -> Result<String> {
        let request = serde_json::json!({
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
            "id": std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_millis() as u64
        });

        let req_bytes = serde_json::to_vec(&request)?;
        let header = (req_bytes.len() as u32).to_le_bytes();

        // Connect to pipe
        let mut pipe = timeout(self.timeout, async {
            loop {
                match ClientOptions::new().open(&self.pipe_name) {
                    Ok(pipe) => return Ok(pipe),
                    Err(e) if e.raw_os_error() == Some(231) => {
                        // ERROR_PIPE_BUSY — retry after short delay
                        tokio::time::sleep(Duration::from_millis(50)).await;
                    }
                    Err(e) => return Err(anyhow!(
                        "CE Bridge not running (pipe not found): {}", e
                    )),
                }
            }
        })
        .await
        .map_err(|_| anyhow!("Timeout connecting to CE pipe"))??;

        // Write request
        pipe.write_all(&header).await?;
        pipe.write_all(&req_bytes).await?;

        // Read response header (4 bytes, with timeout)
        let mut resp_header = [0u8; 4];
        timeout(self.timeout, pipe.read_exact(&mut resp_header))
            .await
            .map_err(|_| anyhow!(
                "CE pipe read timed out after {}s. CE may be frozen or Lua bridge stuck.",
                self.timeout.as_secs()
            ))??;

        let resp_len = u32::from_le_bytes(resp_header) as usize;
        if resp_len > 16 * 1024 * 1024 {
            return Err(anyhow!("Response too large: {} bytes", resp_len));
        }

        // Read response body (with timeout)
        let mut resp_body = vec![0u8; resp_len];
        timeout(self.timeout, pipe.read_exact(&mut resp_body))
            .await
            .map_err(|_| anyhow!(
                "CE pipe read timed out after {}s reading body ({} bytes expected)",
                self.timeout.as_secs(), resp_len
            ))??;

        let response: Value = serde_json::from_slice(&resp_body)
            .map_err(|e| anyhow!("Invalid JSON from CE: {} (first 200 bytes: {:?})",
                e, String::from_utf8_lossy(&resp_body[..resp_body.len().min(200)])))?;

        if let Some(error) = response.get("error") {
            return Ok(serde_json::json!({"success": false, "error": error.to_string()}).to_string());
        }
        if let Some(result) = response.get("result") {
            return Ok(result.to_string());
        }
        Ok(response.to_string())
    }
}
```

- [ ] **Step 4: Write minimal main.rs that compiles**

```rust
mod pipe;

fn main() {
    println!("ce-mcp-rs placeholder");
}
```

- [ ] **Step 5: Verify it compiles**

```bash
cargo build
```

Expected: compiles without errors.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "Initial scaffold: Cargo.toml + async pipe client with timeout"
```

---

### Task 2: MCP server with first 3 tools (ping, evaluate_lua, get_process_info)

**Files:**
- Create: `src/tools.rs`
- Modify: `src/main.rs`

- [ ] **Step 1: Write tools.rs with the MCP server struct and first 3 tools**

```rust
use crate::pipe::PipeClient;
use rmcp::{
    handler::server::router::tool::ToolRouter,
    handler::server::tool::Parameters,
    model::*,
    schemars, tool, tool_handler, tool_router, ServerHandler,
};
use serde::Deserialize;
use std::borrow::Cow;
use std::sync::Arc;

#[derive(Debug, Clone)]
pub struct CeServer {
    pipe: Arc<PipeClient>,
    tool_router: ToolRouter<CeServer>,
}

fn ce_error(msg: String) -> ErrorData {
    ErrorData {
        code: ErrorCode(-32603),
        message: Cow::from(msg),
        data: None,
    }
}

// Parameter structs for tools with arguments
#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct EvaluateLuaParams {
    #[schemars(description = "Lua code to execute in Cheat Engine")]
    pub code: String,
}

#[tool_router]
impl CeServer {
    pub fn new() -> Self {
        Self {
            pipe: Arc::new(PipeClient::new()),
            tool_router: Self::tool_router(),
        }
    }

    #[tool(description = "Check connectivity and get version info.")]
    async fn ping(&self) -> Result<CallToolResult, ErrorData> {
        let result = self.pipe.send_command("ping", serde_json::json!({}))
            .await
            .map_err(|e| ce_error(e.to_string()))?;
        Ok(CallToolResult::success(vec![Content::text(result)]))
    }

    #[tool(description = "Execute arbitrary Lua code in Cheat Engine.")]
    async fn evaluate_lua(
        &self,
        Parameters(params): Parameters<EvaluateLuaParams>,
    ) -> Result<CallToolResult, ErrorData> {
        let result = self.pipe
            .send_command("evaluate_lua", serde_json::json!({"code": params.code}))
            .await
            .map_err(|e| ce_error(e.to_string()))?;
        Ok(CallToolResult::success(vec![Content::text(result)]))
    }

    #[tool(description = "Get current process ID, name, modules count and architecture.")]
    async fn get_process_info(&self) -> Result<CallToolResult, ErrorData> {
        let result = self.pipe.send_command("get_process_info", serde_json::json!({}))
            .await
            .map_err(|e| ce_error(e.to_string()))?;
        Ok(CallToolResult::success(vec![Content::text(result)]))
    }
}

#[tool_handler]
impl ServerHandler for CeServer {
    fn get_info(&self) -> ServerInfo {
        ServerInfo {
            protocol_version: ProtocolVersion::V_2024_11_05,
            capabilities: ServerCapabilities::builder().enable_tools().build(),
            server_info: Implementation {
                name: "cheatengine".into(),
                version: env!("CARGO_PKG_VERSION").into(),
            },
            instructions: Some(
                "Cheat Engine MCP Bridge — read/write memory, scan, debug, execute Lua".into(),
            ),
        }
    }
}
```

- [ ] **Step 2: Update main.rs to run the MCP server**

```rust
mod pipe;
mod tools;

use anyhow::Result;
use rmcp::ServiceExt;
use tools::CeServer;

#[tokio::main]
async fn main() -> Result<()> {
    // Log to stderr (stdout is reserved for MCP JSON-RPC)
    tracing_subscriber::fmt()
        .with_env_filter("ce_mcp_rs=info")
        .with_writer(std::io::stderr)
        .init();

    tracing::info!("ce-mcp-rs starting");
    let service = CeServer::new().serve(rmcp::transport::stdio()).await?;
    service.waiting().await?;
    Ok(())
}
```

- [ ] **Step 3: Build and verify**

```bash
cargo build --release
```

Expected: compiles. Binary at `target/release/ce-mcp-rs.exe`.

- [ ] **Step 4: Test with Claude Code**

Update `.mcp.json` in a test project:
```json
{
  "mcpServers": {
    "cheatengine": {
      "command": "C:/dev/cheatengine-mcp-rs/target/release/ce-mcp-rs.exe"
    }
  }
}
```

Test: `ping` tool should work if CE + Lua bridge is running.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Add MCP server with ping, evaluate_lua, get_process_info"
```

---

### Task 3: Add all remaining 40 tools

**Files:**
- Modify: `src/tools.rs`

The remaining tools follow the same pattern. Each tool needs a parameter struct (if it has arguments) and a `#[tool]` function. Group them by category.

- [ ] **Step 1: Add parameter structs for all tools with arguments**

Add to `src/tools.rs` — parameter structs for every tool that takes arguments. Each struct derives `Debug, Deserialize, schemars::JsonSchema` and each field has a `#[schemars(description = "...")]` attribute.

Tools with NO parameters (just call and return): `enum_modules`, `get_thread_list`, `list_breakpoints`, `clear_all_breakpoints`, `ping`, `get_process_info`

Tools WITH parameters: all others. Create one struct per tool. Use the Python server (lines 302-557 of `mcp_cheatengine.py`) as the reference for exact parameter names, types, and defaults.

For optional parameters, use `Option<T>` with `#[serde(default)]`:
```rust
#[derive(Debug, Deserialize, schemars::JsonSchema)]
pub struct ReadMemoryParams {
    #[schemars(description = "Memory address to read from")]
    pub address: String,
    #[schemars(description = "Number of bytes to read")]
    #[serde(default = "default_256")]
    pub size: i64,
}
fn default_256() -> i64 { 256 }
```

- [ ] **Step 2: Add all tool functions**

Each tool follows the same pattern:
```rust
#[tool(description = "...")]
async fn tool_name(
    &self,
    Parameters(p): Parameters<ToolNameParams>,
) -> Result<CallToolResult, ErrorData> {
    let result = self.pipe
        .send_command("tool_name", serde_json::json!({...params...}))
        .await
        .map_err(|e| ce_error(e.to_string()))?;
    Ok(CallToolResult::success(vec![Content::text(result)]))
}
```

For no-parameter tools:
```rust
#[tool(description = "...")]
async fn tool_name(&self) -> Result<CallToolResult, ErrorData> {
    let result = self.pipe.send_command("tool_name", serde_json::json!({}))
        .await
        .map_err(|e| ce_error(e.to_string()))?;
    Ok(CallToolResult::success(vec![Content::text(result)]))
}
```

Special case — `read_pointer`: has logic to default offsets to `[0]` if not provided:
```rust
#[tool(description = "Read a pointer chain. Returns the final address and value.")]
async fn read_pointer(
    &self,
    Parameters(p): Parameters<ReadPointerParams>,
) -> Result<CallToolResult, ErrorData> {
    let offsets = p.offsets.unwrap_or_else(|| vec![0]);
    let result = self.pipe
        .send_command("read_pointer_chain", serde_json::json!({"base": p.address, "offsets": offsets}))
        .await
        .map_err(|e| ce_error(e.to_string()))?;
    Ok(CallToolResult::success(vec![Content::text(result)]))
}
```

Implement all 43 tools matching the Python server exactly. Reference: `C:\dev\cheatenginemcp\MCP_Server\mcp_cheatengine.py` lines 302-557.

- [ ] **Step 3: Build**

```bash
cargo build --release
```

Expected: compiles with all 43 tools.

- [ ] **Step 4: Commit**

```bash
git add src/tools.rs
git commit -m "Add all 43 MCP tools matching Python server"
```

---

### Task 4: End-to-end testing and deployment

**Files:**
- Create: `README.md`

- [ ] **Step 1: Test all tool categories**

With CE running + Lua bridge loaded + game attached:
1. `ping` — returns version info
2. `get_process_info` — returns PID, name, module count
3. `evaluate_lua` with `return 1+1` — returns `2`
4. `read_memory` — reads bytes from game
5. `aob_scan` — scans for byte pattern
6. `set_breakpoint` / `list_breakpoints` / `clear_all_breakpoints` — breakpoint lifecycle

- [ ] **Step 2: Test timeout behavior**

1. Start CE + bridge
2. Call `ping` — should work
3. Close CE (kill process)
4. Call `ping` — should return error within 30s, NOT hang

- [ ] **Step 3: Write README.md**

```markdown
# ce-mcp-rs

Rust MCP server for Cheat Engine. Replaces the Python `mcp_cheatengine.py` with native async I/O and proper timeouts.

## Build

```bash
cargo build --release
```

## Usage

Add to `.mcp.json`:
```json
{
  "mcpServers": {
    "cheatengine": {
      "command": "C:/dev/cheatengine-mcp-rs/target/release/ce-mcp-rs.exe"
    }
  }
}
```

Requires the CE Lua bridge (`ce_mcp_bridge.lua`) loaded in Cheat Engine.

## Environment Variables

- `CE_PIPE_NAME` — pipe name (default: `\\.\pipe\CE_MCP_Bridge_v99`)
- `CE_PIPE_TIMEOUT` — read timeout in seconds (default: 30)
```

- [ ] **Step 4: Commit and push**

```bash
git add -A
git commit -m "Add README and verify all 43 tools"
git remote add origin https://github.com/tantk/cheatengine-mcp-rs.git
git push -u origin main
```

- [ ] **Step 5: Archive Python server**

In the bridge repo (`C:\dev\cheatenginemcp`):
```bash
mkdir -p MCP_Server/legacy
mv MCP_Server/mcp_cheatengine.py MCP_Server/legacy/
git add -A
git commit -m "Archive Python MCP server (replaced by tantk/cheatengine-mcp-rs)"
git push
```

- [ ] **Step 6: Update game repo .mcp.json**

In `C:\dev\longyin-cheats`:
```json
{
  "mcpServers": {
    "cheatengine": {
      "command": "C:/dev/cheatengine-mcp-rs/target/release/ce-mcp-rs.exe"
    }
  }
}
```
