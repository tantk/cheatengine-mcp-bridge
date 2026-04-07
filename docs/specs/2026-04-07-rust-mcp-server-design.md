# Rust CE MCP Server Design

## Overview

Replace the Python MCP server (`mcp_cheatengine.py`) with a Rust implementation. The Python server has a critical blocking pipe bug (no timeout on `ReadFile` — hangs indefinitely when CE is frozen). Rust with tokio provides native async named pipe I/O with proper timeouts.

## New Repo

- **Name:** `tantk/cheatengine-mcp-rs`
- **Local path:** `C:\dev\cheatengine-mcp-rs`
- **Build output:** `target/release/ce-mcp-rs.exe` (single binary, zero deps)

## Architecture

```
Claude Code <-> stdio (JSON-RPC) <-> ce-mcp-rs.exe <-> Named Pipe <-> CE Lua Bridge
```

Same architecture as Python — stdio MCP server proxying to CE's Lua bridge over a named pipe. The Lua bridge is unchanged.

## Components

### 1. Pipe Client (`src/pipe.rs`)
- Async named pipe via `tokio::net::windows::named_pipe::ClientOptions`
- 30s timeout on every read via `tokio::time::timeout`
- Length-prefixed protocol: 4-byte LE header + JSON body (same as Python)
- Auto-reconnect on pipe error (1 retry)
- Clean error on timeout — no hanging

### 2. MCP Server (`src/main.rs` + `src/tools.rs`)
- `rmcp` crate with stdio transport
- 43 tools matching the current Python server exactly
- Each tool calls `pipe_client.send_command(method, params)` and returns the JSON result
- `#[tool]` macro for each tool definition

### 3. Config (`src/config.rs`)
- Pipe name: `\\.\pipe\CE_MCP_Bridge_v99` (hardcoded default, env override via `CE_PIPE_NAME`)
- Timeout: 30s default, env override via `CE_PIPE_TIMEOUT`

## Data Flow

1. Claude calls MCP tool (e.g., `evaluate_lua`)
2. rmcp receives JSON-RPC via stdin
3. Tool handler serializes request as JSON
4. Pipe client: write 4-byte length header + JSON body
5. Pipe client: read 4-byte response header (with 30s timeout)
6. Pipe client: read response body (with 30s timeout)
7. Return result via stdout JSON-RPC

## Error Handling

| Scenario | Behavior |
|---|---|
| CE not running | Immediate error: "Pipe not found" |
| CE frozen (no response) | 30s timeout, then error: "CE pipe read timed out" |
| Pipe disconnected mid-command | Error + auto-reconnect on next command |
| Invalid JSON from CE | Error with first 200 bytes of response |
| Response > 16MB | Reject as too large |

## Tool List (43 tools — exact match with Python)

### Process & Modules
- `get_process_info`, `enum_modules`, `get_thread_list`, `get_symbol_address`, `get_address_info`, `get_rtti_classname`

### Memory Reading
- `read_memory`, `read_integer`, `read_string`, `read_pointer`, `read_pointer_chain`, `checksum_memory`

### Scanning
- `scan_all`, `get_scan_results`, `next_scan`, `aob_scan`, `search_string`, `generate_signature`, `get_memory_regions`, `enum_memory_regions_full`

### Memory Writing
- `write_integer`, `write_memory`, `write_string`

### Analysis & Disassembly
- `disassemble`, `get_instruction_info`, `find_function_boundaries`, `analyze_function`, `find_references`, `find_call_references`, `dissect_structure`

### Debugging & Breakpoints
- `set_breakpoint`, `set_data_breakpoint`, `remove_breakpoint`, `list_breakpoints`, `clear_all_breakpoints`, `get_breakpoint_hits`

### DBVM / Hypervisor
- `get_physical_address`, `start_dbvm_watch`, `stop_dbvm_watch`, `poll_dbvm_watch`

### Scripting & Control
- `evaluate_lua`, `auto_assemble`, `ping`

## Dependencies

```toml
[dependencies]
rmcp = { version = "0.16", features = ["server", "transport-io", "macros"] }
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
```

## What Does NOT Change

- Lua bridge (`ce_mcp_bridge.lua`) — untouched
- Named pipe protocol — same length-prefixed JSON
- Tool names and parameters — identical to Python
- CE autorun (`autorun/mcpstart.lua`) — untouched

## Migration

1. Build: `cargo build --release`
2. Update `.mcp.json` in game repo:
   ```json
   {
     "mcpServers": {
       "cheatengine": {
         "command": "C:/dev/cheatengine-mcp-rs/target/release/ce-mcp-rs.exe"
       }
     }
   }
   ```
3. Archive Python server: move `mcp_cheatengine.py` to `MCP_Server/legacy/`

## Verification

- [ ] `ping` tool returns CE bridge version
- [ ] `evaluate_lua` executes Lua and returns result
- [ ] `read_memory` reads from game process
- [ ] Timeout works: disconnect CE mid-command, server responds with error within 30s
- [ ] All 43 tools callable from Claude Code
