# Quickstart Guide

Get Retrace built and running on your Mac in under 15 minutes.

## Prerequisites

| Requirement | Minimum | Check command |
|---|---|---|
| macOS | 13.0 (Ventura) | `sw_vers` |
| Apple Silicon | M1 / M2 / M3 / M4 | `uname -m` (expect `arm64`) |
| Xcode | 15.0+ (or Command Line Tools) | `xcodebuild -version` |
| Swift | 5.9+ | `swift --version` |
| Git | any recent | `git --version` |

**Optional (for release builds and linting):**

| Tool | Install | Purpose |
|---|---|---|
| XcodeGen | `brew install xcodegen` | Generate `.xcodeproj` from `project.yml` |
| SwiftLint | `brew install swiftlint` | Lint Swift code |
| SwiftFormat | `brew install swiftformat` | Auto-format Swift code |

## 1. Clone the repository

```bash
git clone https://github.com/haseab/retrace.git
cd retrace
```

Or, if you plan to contribute, fork first:

```bash
gh repo fork haseab/retrace --clone
cd retrace
```

## 2. Resolve dependencies

Swift Package Manager fetches two external packages (swift-sqlcipher and Sparkle):

```bash
swift package resolve
```

This takes about 1--2 minutes on the first run. Dependencies are pinned in `Package.resolved`.

## 3. Build

**Debug (fast iteration):**

```bash
swift build
```

**Release (optimized):**

```bash
swift build -c release
```

First build compiles all modules and takes approximately **3--8 minutes** depending on your machine. Subsequent incremental builds are much faster.

## 4. Run

**Option A -- Command line (debug):**

```bash
./dev.sh
# or directly:
.build/debug/Retrace
```

**Option B -- Signed app bundle (recommended for permissions):**

```bash
./build_and_sign.sh
# Then:
open .build/release/Retrace.app
# Or install to /Applications for persistent permissions:
# cp -r .build/release/Retrace.app /Applications/ && open /Applications/Retrace.app
```

**Option C -- Xcode:**

```bash
open Package.swift
```

Select the **Retrace** scheme, then Build and Run (Cmd+R).

## 5. First launch

On first run Retrace will request two macOS permissions:

1. **Screen Recording** -- System Settings > Privacy & Security > Screen Recording
2. **Accessibility** -- System Settings > Privacy & Security > Accessibility

Grant both, then complete the onboarding flow. Optionally import existing Rewind AI data if you have it.

Data is stored at `~/Library/Application Support/Retrace/` by default.

## 6. Run tests

```bash
swift test
```

Run a specific module's tests:

```bash
swift test --filter DatabaseTests
swift test --filter StorageTests
swift test --filter CaptureTests
```

## 7. Automated setup (optional)

A helper script verifies your environment and runs the full build + test cycle:

```bash
./scripts/setup_dev.sh
```

This checks prerequisites, resolves packages, builds in release mode, and runs the test suite. It will report exactly what is missing if anything fails.

## Time estimates

| Step | Time |
|---|---|
| Clone | <1 min |
| `swift package resolve` (first time) | 1--2 min |
| `swift build` (first full build) | 3--8 min |
| `swift build` (incremental) | 5--30 sec |
| `swift test` | 1--3 min |
| **Total: clone to first run** | **~5--15 min** |

## What's next

- **[README.md](README.md)** -- Project overview, features, and roadmap
- **[CONTRIBUTING.md](CONTRIBUTING.md)** -- Development workflow, coding standards, and PR process
- **[AGENTS.md](AGENTS.md)** -- Architecture reference and module-level agent instructions
- **[ARCHITECTURE.md](ARCHITECTURE.md)** -- Detailed architecture and data flow
- **[DIAGRAMS.md](DIAGRAMS.md)** -- Visual diagrams (Mermaid) of architecture, data flow, and schema
- **[DEBUGGING.md](DEBUGGING.md)** -- Debug logging, tracing, and troubleshooting

## Contributing from a fork

If you cloned via `gh repo fork` above, your remotes are already set up (`origin` = your fork, `upstream` = haseab/retrace). To contribute:

```bash
# Keep your fork in sync
git fetch upstream
git rebase upstream/main

# Create a feature branch
git checkout -b feature/my-change

# Make changes, test, commit (see CONTRIBUTING.md for commit format)
swift test
git add -A && git commit -m "feat(module): short description"

# Push and open a PR
git push -u origin feature/my-change
gh pr create --web
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full workflow, commit conventions, and PR template.
