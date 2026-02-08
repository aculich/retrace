# Debugging Guide

All Retrace debug output goes to a single file: `/tmp/retrace_debug.log`. This is the single source of truth for runtime debugging.

---

## Quick Reference

```bash
# Watch logs in real-time
tail -f /tmp/retrace_debug.log

# Watch logs filtered to a specific area
tail -f /tmp/retrace_debug.log | grep "TIMELINE"

# View last 100 lines
tail -100 /tmp/retrace_debug.log

# Search for a pattern
grep "DEBUG-LOAD" /tmp/retrace_debug.log

# Clear the log (do this before each debugging session)
: > /tmp/retrace_debug.log
```

---

## Clear Before Each Session

Always start a new debugging session with a clean log:

```bash
# Fastest -- shell builtin
: > /tmp/retrace_debug.log

# Alternatives
cat /dev/null > /tmp/retrace_debug.log
truncate -s 0 /tmp/retrace_debug.log
```

One-liner to clear and watch:

```bash
: > /tmp/retrace_debug.log && tail -f /tmp/retrace_debug.log | grep "KEYWORD"
```

---

## Writing Debug Logs (Swift)

Use the pattern established in `Shared/Logging.swift` or the static helper used throughout the codebase:

```swift
private static func logDebugFileStatic(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(message)\n"
    let path = URL(fileURLWithPath: "/tmp/retrace_debug.log")

    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: path.path) {
            if let handle = try? FileHandle(forWritingTo: path) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: path)
        }
    }
}
```

Call it from any layer:

```swift
logDebugFileStatic("[CAPTURE] Frame captured: \(frameId)")
logDebugFileStatic("[OCR] Extracted \(regions.count) regions")
logDebugFileStatic("[DB] Inserted frame at \(timestamp)")
```

---

## Debugging Philosophy: Trace Execution First

**Do not assume you know which code path is running.** Add logging at each layer to trace the actual execution path before making changes:

```swift
debugLog("[VM] -> Calling coordinator")
debugLog("[COORDINATOR] -> Calling adapter")
debugLog("[ADAPTER] -> Taking FILTERED path")   // Reveals which branch runs
```

Then check which path actually executes and fix the right code.

---

## Common Debug Scenarios

### App does not capture

1. Check Screen Recording permission: System Settings > Privacy & Security > Screen Recording
2. Check Accessibility permission: same location
3. Look for permission errors in the log:
   ```bash
   grep -i "permission" /tmp/retrace_debug.log
   ```

### Search returns no results

1. Verify frames are being captured and indexed:
   ```bash
   grep "INSERT\|index\|ingest" /tmp/retrace_debug.log
   ```
2. Check the database directly:
   ```bash
   sqlite3 ~/Library/Application\ Support/Retrace/retrace.db "SELECT COUNT(*) FROM frame;"
   ```

### High CPU or memory usage

1. Open Activity Monitor and filter for "Retrace"
2. Check the capture interval (default 2 s; lower values use more CPU)
3. Look for OCR bottlenecks:
   ```bash
   grep "OCR\|processing" /tmp/retrace_debug.log | tail -20
   ```

### Timeline is blank

1. Check if frames exist in the database
2. Check if video segments exist on disk:
   ```bash
   ls -la ~/Library/Application\ Support/Retrace/videos/ | head -20
   ```
3. Watch the log for frame loading:
   ```bash
   grep "TIMELINE\|LOAD\|frame" /tmp/retrace_debug.log
   ```

---

## Instruments and Profiling

For deeper performance analysis, use Xcode Instruments:

1. Open the project in Xcode (`open Package.swift`)
2. Product > Profile (Cmd+I)
3. Choose a template:
   - **Time Profiler** -- CPU hotspots
   - **Allocations** -- Memory usage and leaks
   - **System Trace** -- Thread scheduling and I/O
   - **Metal System Trace** -- GPU/VideoToolbox (HEVC encoding)

---

## Useful Scripts

| Script | Purpose |
|---|---|
| `scripts/reset_database.sh` | Delete and recreate the database |
| `scripts/reset_onboarding_safe.sh` | Reset onboarding flow (preserves data) |
| `scripts/hardreset_onboarding.sh` | Full reset (deletes everything) |
| `scripts/reset_app.sh` | Reset app state |

---

## Further Reading

- [AGENTS.md](AGENTS.md) -- Debug logging conventions and the `debugFile()` API
- [ARCHITECTURE.md](ARCHITECTURE.md) -- Module layout to know where to add logs
- [CONTRIBUTING.md](CONTRIBUTING.md) -- Testing requirements and TDD workflow
