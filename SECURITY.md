# Security Policy

Retrace is designed as a **local-first, privacy-preserving** application. All data capture, processing, and storage happens entirely on your device.

---

## Core Principles

1. **No cloud, no telemetry.** Retrace makes no network calls for its core functionality. No usage data, crash reports, or analytics are sent anywhere.
2. **Encryption at rest.** Database and stored data can be encrypted with AES-256-GCM via Apple's CryptoKit framework.
3. **Permission-gated access.** Screen Recording and Accessibility permissions are requested gracefully; the app degrades cleanly if denied.
4. **Open source.** The full source code is available for audit.

---

## Data Storage

| Data | Location | Encrypted |
|---|---|---|
| Database (frames, OCR text, metadata) | `~/Library/Application Support/Retrace/retrace.db` | Optional (AES-256-GCM) |
| Video recordings (HEVC) | `~/Library/Application Support/Retrace/videos/` | Optional |
| Debug logs | `/tmp/retrace_debug.log` | No (temporary, auto-cleared) |
| User preferences | macOS UserDefaults (`io.retrace.app`) | No (non-sensitive settings only) |

---

## Privacy Controls

- **App exclusion list** -- Configure apps that should never be captured (e.g., password managers, banking apps).
- **Private browsing detection** -- Automatically detects and skips private/incognito browser windows.
- **Data retention policies** -- Configurable auto-deletion of data older than a specified period.
- **Pause/resume** -- Capture can be paused at any time via the menu bar.

---

## Secure Coding Practices

- **Parameterized SQL** -- All database queries use parameter binding (`sqlite3_bind_*`). No string interpolation in SQL.
- **No sensitive logging** -- Debug logs must never contain passwords, tokens, encryption keys, or user-sensitive content.
- **Actor isolation** -- All stateful managers use Swift actors for thread-safe concurrent access.
- **Hardened runtime** -- Release builds use macOS hardened runtime with appropriate entitlements.

---

## macOS Permissions

Retrace requires these permissions to function:

| Permission | Purpose | What happens without it |
|---|---|---|
| Screen Recording | Capture screen content via CGWindowListCapture | App cannot capture; prompts user |
| Accessibility | Extract app names, window titles, browser URLs | Reduced metadata; capture still works |

Permissions are requested during onboarding and can be managed in System Settings > Privacy & Security.

---

## Dependencies

External dependencies are minimal and auditable:

| Dependency | Purpose | License |
|---|---|---|
| [swift-sqlcipher](https://github.com/skiptools/swift-sqlcipher) | SQLite with encryption (for Rewind import) | BSD |
| [Sparkle](https://github.com/sparkle-project/Sparkle) | Auto-update framework | MIT |

All other functionality uses Apple system frameworks (Vision, VideoToolbox, CryptoKit, CoreGraphics).

---

## Reporting Vulnerabilities

If you discover a security vulnerability in Retrace, please report it responsibly:

1. **Do not** open a public GitHub issue for security vulnerabilities.
2. Email the maintainer directly (see the project README for contact information).
3. Include a description of the vulnerability, steps to reproduce, and potential impact.
4. Allow reasonable time for a fix before public disclosure.

We aim to acknowledge reports within 48 hours and provide a fix or mitigation plan within 7 days.

---

## CI/CD Security

- **CodeQL** -- Automated code scanning runs on every push and PR (see `.github/workflows/codeql.yml`).
- **CodeRabbit** -- AI-assisted PR review checks for security anti-patterns.
- **Dependency auditing** -- Swift Package Manager lockfile (`Package.resolved`) is committed for reproducible builds.

---

## Further Reading

- [ARCHITECTURE.md](ARCHITECTURE.md) -- System design and security model
- [CONTRIBUTING.md](CONTRIBUTING.md) -- Secure coding standards for contributors
- [AGENTS.md](AGENTS.md) -- Module-level security responsibilities
