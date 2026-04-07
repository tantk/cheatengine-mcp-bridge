# Handover: Rust CE MCP Server

## What We're Building

A Rust replacement for the Python MCP server (`MCP_Server/mcp_cheatengine.py`). The Python server has a critical bug — blocking pipe reads with no timeout that cause 40+ minute hangs when CE freezes.

**Spec:** `docs/specs/2026-04-07-rust-mcp-server-design.md`

## New Repo

- **Name:** `tantk/cheatengine-mcp-rs`
- **Local path:** `C:\dev\cheatengine-mcp-rs`
- **GitHub:** Create as public repo

## Key Research

### Rust MCP SDK (rmcp)
- Official SDK: https://github.com/modelcontextprotocol/rust-sdk
- Crate: `rmcp` v0.16.0
- Features needed: `server`, `transport-io`, `macros`
- Uses tokio async runtime
- `#[tool]` macro for declaring tools
- Stdio transport: `tokio::io::{stdin, stdout}`
- Example: https://www.shuttle.dev/blog/2025/07/18/how-to-build-a-stdio-mcp-server-in-rust
- DeepWiki transport examples: https://deepwiki.com/modelcontextprotocol/rust-sdk/5.4-transport-examples

### Windows Named Pipes in Tokio
- `tokio::net::windows::named_pipe` module
- Docs: https://docs.rs/tokio/latest/src/tokio/net/windows/named_pipe.rs.html
- Client: `ClientOptions::new().open(pipe_name)`
- Async read/write with proper timeout via `tokio::time::timeout`
- No thread hacks needed — native async I/O

### Pipe Protocol (from current Python server)
```
Request:  [4-byte LE length] [JSON-RPC request body]
Response: [4-byte LE length] [JSON-RPC response body]

JSON-RPC request format:
{
  "jsonrpc": "2.0",
  "method": "evaluate_lua",
  "params": {"code": "return 1+1"},
  "id": 1234567890
}

Response format:
{
  "jsonrpc": "2.0",
  "result": "{\"result\": \"2\", \"success\": true}",
  "id": 1234567890
}
```

### Current Python Server Issues (why we're replacing it)
1. `win32file.ReadFile` blocks indefinitely — no timeout (caused 40+ min hangs)
2. ThreadPoolExecutor timeout hack creates/destroys thread pool per read
3. 75 lines of monkey-patching MCP SDK for Windows CRLF bug
4. Synchronous pipe calls block the async event loop
5. JSON double-serialization (parse then re-serialize)
6. `self.handle = None` duplicated in close()
7. No async anywhere despite using FastMCP (async framework)
8. Pipe handle leak on timeout — background thread still blocked

### Pipe Name
- Default: `\\.\pipe\CE_MCP_Bridge_v99`
- Set in Lua bridge at `ce_mcp_bridge.lua` line ~30

### Tool Definitions Reference
Read the current Python server for exact tool names, parameters, and descriptions:
`C:\dev\cheatenginemcp\MCP_Server\mcp_cheatengine.py` (lines 302-557)

All 43 tools are thin wrappers:
```python
@mcp.tool()
def evaluate_lua(code: str) -> str:
    """Execute arbitrary Lua code in Cheat Engine."""
    return format_result(ce_client.send_command("evaluate_lua", {"code": code}))
```

The Rust equivalent should be:
```rust
#[tool(description = "Execute arbitrary Lua code in Cheat Engine.")]
async fn evaluate_lua(&self, code: String) -> String {
    self.pipe.send_command("evaluate_lua", json!({"code": code})).await
}
```

### What format_result Does (Python)
Wraps the CE bridge response in JSON. In Rust, just pass through the JSON string — no re-serialization needed.

### Dependencies (minimal)
```toml
[dependencies]
rmcp = { version = "0.16", features = ["server", "transport-io", "macros"] }
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
```

87 crate dependencies total, compiles to single binary (~2-5MB).

### .mcp.json Configuration
```json
{
  "mcpServers": {
    "cheatengine": {
      "command": "C:/dev/cheatengine-mcp-rs/target/release/ce-mcp-rs.exe"
    }
  }
}
```

## Files to Reference

| File | What it contains |
|---|---|
| `C:\dev\cheatenginemcp\MCP_Server\mcp_cheatengine.py` | Current Python server (570 lines) — tool definitions, pipe protocol |
| `C:\dev\cheatenginemcp\MCP_Server\ce_mcp_bridge.lua` | Lua bridge (unchanged) — pipe server side |
| `C:\dev\cheatenginemcp\AI_Context\MCP_Bridge_Command_Reference.md` | All 43 MCP tools documented |
| `C:\dev\cheatenginemcp\docs\specs\2026-04-07-rust-mcp-server-design.md` | Design spec |

## Verification Steps

1. `cargo build --release` compiles without errors
2. `ping` tool returns CE bridge version info
3. `evaluate_lua` with `return 1+1` returns `2`
4. Timeout test: disconnect CE, call any tool, get error within 30s (not hang)
5. All 43 tools callable from Claude Code
6. Reconnection: restart CE, next tool call auto-reconnects

## After Implementation

1. Archive Python server: `MCP_Server/mcp_cheatengine.py` → `MCP_Server/legacy/mcp_cheatengine.py`
2. Update `.mcp.json` in `C:\dev\longyin-cheats` to point to Rust binary
3. Update `CLAUDE.md` in bridge repo to reference Rust server
