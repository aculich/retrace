# Architecture

Retrace is a **local-first** screen recording and search application for macOS. It continuously captures screenshots, extracts text via OCR, and makes everything searchable -- all on-device with no cloud dependencies.

This document describes the system architecture, module responsibilities, data flow, and key design decisions.

---

## Design Goals

1. **Local-first** -- All data stays on-device. No network calls for core functionality.
2. **Modular** -- Strict module boundaries with protocol-based interfaces.
3. **Performant** -- <20% CPU, <1 GB RAM, sub-100 ms search on Apple Silicon.
4. **Privacy-preserving** -- Optional encryption at rest (SQLCipher for `retrace.db` when enabled, Keychain-backed key; CryptoKit for other protected payloads), no telemetry, app exclusion support.
5. **Extensible** -- Prepared for audio transcription (whisper.cpp) and semantic search (llama.cpp).

---

## System Overview

Retrace is a single macOS app built with Swift 5.9+ and SwiftUI. It runs as a menu-bar application with a global hotkey overlay. The architecture follows a layered, modular pattern:

```
+---------------------------------------------------------+
|                     UI Layer (SwiftUI)                   |
|  RetraceApp, ContentView, ViewModels, Views, Components |
+---------------------------------------------------------+
|                   App Coordination Layer                  |
|  AppCoordinator, ServiceContainer, DataAdapter           |
+---------------------------------------------------------+
|                     Feature Modules                       |
|  Capture | Processing | Search | Migration               |
+---------------------------------------------------------+
|                     Storage Layer                         |
|  Storage (HEVC video)  |  Database (SQLite + FTS5)       |
+---------------------------------------------------------+
|                     Shared Foundation                     |
|  Protocols, Models, Logging, AppPaths                    |
+---------------------------------------------------------+
```

---

## Modules

### Shared (`Shared/`)

The foundation layer containing types and protocols imported by every other module. No module-specific logic lives here.

| Sub-path | Contents |
|---|---|
| `Models/` | `Frame`, `Segment`, `Text`, `TextRegion`, `Search`, `Config`, `Errors`, `Audio`, `FilterCriteria`, `Source`, `Tag` |
| `Protocols/` | `DatabaseProtocol`, `StorageProtocol`, `CaptureProtocol`, `ProcessingProtocol`, `SearchProtocol`, `MigrationProtocol` |
| `Logging.swift` | Unified logging + `debugFile()` writing to `/tmp/retrace_debug.log` |
| `AppPaths.swift` | Canonical paths for database, storage root, and config |
| `PowerStateMonitor.swift` | Monitors sleep/wake to pause capture |

### Database (`Database/`)

SQLite database with FTS5 full-text search, using SQLCipher for optional encryption and Rewind import compatibility.

| Component | Purpose |
|---|---|
| `DatabaseManager` (actor) | Main coordinator implementing `DatabaseProtocol` |
| `DatabaseConnection` | Low-level SQLite connection management |
| `FTSManager` | Full-text search operations |
| `IDMappingService` | ID mapping between Retrace and imported (Rewind) sources |
| `Schema.swift` | Table name constants, pragmas, and schema helpers (Rewind-compatible layout) |
| `Migrations/` | Versioned migrations **V1 through V13** (`MigrationRunner`): initial schema, video finalization, tags, daily metrics, FTS tokenizer upgrade, frame processing timestamps, redaction, segment comments (+ FTS for comments), frame metadata, in-page URL cleanup |
| `Queries/` | Frame, Segment, AppSegment, Document, Node, FTS (`FTSQueries`), DailyMetrics |

**Core tables:** `segment`, `frame`, `node`, `video`, `searchRanking` (FTS5), `searchRanking_content`, `doc_segment`, `videoFileState`, `schema_migrations`.

**Additional tables (evolved via migrations):** `tag`, `segment_tag`, `daily_metrics`, `segment_comment`, `frame_processing`, `purge`, plus `audio`, `transcript_word`, `event`, and `summary` from the initial schema (reserved for future audio / meeting-style features; not all are exercised in the current UI).

### Storage (`Storage/`)

File I/O and HEVC video encoding for captured frames.

| Component | Purpose |
|---|---|
| `StorageManager` (actor) | Implements `StorageProtocol`; manages file lifecycle |
| `ImageExtractor` | Extracts individual frames from encoded video files |
| `IncrementalSegmentWriter` | Writes frames into video segments incrementally |
| `SegmentWriterImpl` | Segment writing implementation |
| `VideoEncoder/` | `HEVCEncoder` (hardware-accelerated on Apple Silicon), `FrameConverter` |
| `WAL/` | Write-Ahead Log (`WALManager`, `RecoveryManager`) for crash-safe writes |
| `FileManager/` | `DirectoryManager`, `StorageHealthMonitor` |

Encoded segments are written under **`chunks/`** beneath the configured storage root (`AppPaths.storageRoot`, tilde-expanded at runtime) with layout `chunks/YYYYMM/DD/<videoSegmentId>` (files are HEVC in an MP4 container but typically **extensionless** on disk; paths are stored relative to the storage root). **`retrace.db`** is a sibling of the `chunks/` directory (`AppPaths.databasePath`). `AppPaths` also defines `segments/` and `temp/` under the same root for compatibility and auxiliary use; primary capture output uses **`chunks/`** via `DirectoryManager`.

### Capture (`Capture/`)

Continuous screen capture using the CGWindowListCapture API.

| Component | Purpose |
|---|---|
| `CaptureManager` (actor) | Implements `CaptureProtocol`; orchestrates capture loop (default every 2 s) |
| `ScreenCapture/` | `CGWindowListCapture`, `DisplayMonitor`, `DisplaySwitchMonitor`, `PermissionChecker`, `PermissionMonitor`, `PrivateWindowDetector`, `PrivateWindowMonitor` |
| `Deduplication/` | `FrameDeduplicator`, `PerceptualHash` -- filters ~95% of duplicate frames |
| `Metadata/` | `AppInfoProvider` (bundle ID, app name, window title), `BrowserURLExtractor` |

### Processing (`Processing/`)

OCR text extraction and accessibility metadata.

| Component | Purpose |
|---|---|
| `ProcessingManager` (actor) | Implements `ProcessingProtocol`; coordinates OCR pipeline |
| `FrameProcessingQueue` | Async queue for frame-level processing |
| `OCR/` | `VisionOCR`, `TileOCRProcessor`, `TileGridConfig`, `TileChangeDetector`, `RegionOCRMerger`, `RegionOCRResult`, `FullFrameOCRCache`, `OCRTileCache` |
| `Accessibility/` | `AccessibilityService` for enhanced context (app names, URLs) |
| `TextMerger/` | Merges OCR regions into coherent text blocks |
| `URLExtractor` | Extracts URLs from OCR text |

### Search (`Search/`)

Query parsing, FTS5 search execution, and result ranking.

| Component | Purpose |
|---|---|
| `SearchManager` (actor) | Implements `SearchProtocol`; executes searches |
| `IngestionManager` | Indexes processed text into FTS5 |
| `QueryParser/` | Parses query syntax: `app:`, `date:`, `-exclude` |
| `Ranking/` | `ResultRanker` -- BM25-based relevance scoring |
| `VectorSearchTODO/` | Planned: `HybridSearchManager`, `LocalEmbeddingService`, `SQLiteVectorStore` (excluded from build) |

### Migration (`Migration/`)

Import data from other screen recording applications.

| Component | Purpose |
|---|---|
| `MigrationManager` (actor) | Implements `MigrationProtocol`; orchestrates imports |
| `Importers/RewindImporter` | Reads Rewind AI encrypted SQLite database (via SQLCipher) |

### App (`App/`)

Application-level coordination and dependency injection.

| Component | Purpose |
|---|---|
| `AppCoordinator` | Central orchestrator: starts/stops capture, wires modules together |
| `ServiceContainer` (actor) | Dependency injection; creates and holds all module managers |
| `DataAdapter` | Data layer facade; translates between DB queries and view model needs |
| `AppLifecycle` | Handles launch, activation, termination |
| `ModelManager` | Manages ML model downloads (whisper/llama, future) |
| `OnboardingManager` | First-run onboarding flow state |
| `RetentionManager` | Data retention policies (auto-delete old data) |

### UI (`UI/`)

SwiftUI interface with a menu-bar presence and global hotkeys.

| Component | Purpose |
|---|---|
| `RetraceApp.swift` | `@main` app entry point |
| `ContentView.swift` | Root view |
| `ViewModels/` | `SimpleTimelineViewModel`, `SearchViewModel`, `DashboardViewModel`, `FeedbackViewModel`, `AppCoordinatorWrapper` |
| `Views/FullscreenTimeline/` | Timeline scrubbing and playback (10 views) |
| `Views/Search/` | Search UI with result highlighting |
| `Views/Dashboard/` | App usage analytics and system monitor |
| `Views/Settings/` | Comprehensive settings panel |
| `Views/Onboarding/` | First-run onboarding flow |
| `Views/Feedback/` | Feedback form and submission |
| `Components/` | `MenuBarManager`, `HotkeyManager`, `AppTheme`, `FilterPopoverComponents`, `UpdaterManager` (Sparkle), and more |

---

## Data Flow

### Capture Pipeline

```
CGWindowListCapture (every 2 seconds)
        |
        v
  FrameDeduplicator (perceptual hash, ~95% filtered out)
        |
        v
  Split into two parallel paths:
        |                          |
        v                          v
  Video Path                  OCR Path
  HEVCEncoder -> .mp4         VisionOCR -> ExtractedText
  StorageManager               ProcessingManager
        |                          |
        v                          v
  Storage on disk             DatabaseManager
  {storageRoot}/chunks/       SQLite + FTS5 index
                                   |
                                   v
                              SearchManager
                              IngestionManager
```

### Search Pipeline

```
User query string
        |
        v
  QueryParser (app:, date:, -exclude filters)
        |
        v
  FTSManager (FTS5 MATCH with BM25 ranking)
        |
        v
  ResultRanker (relevance scoring)
        |
        v
  SearchResult[] (frameId, snippet, highlighting)
        |
        v
  UI: SearchView, FrameViewer, Timeline navigation
```

---

## Database Schema

Core tables and relationships:

```
segment (1) ----< (N) frame (N) >---- (1) video
                       |
                       | 1:N
                       v
                     node (OCR bounding boxes)

frame (1) ----< (1) doc_segment >---- (1) searchRanking_content
```

| Table | Purpose |
|---|---|
| `segment` | App sessions: bundle ID, app name, window title, start/end time |
| `frame` | Individual captures: timestamp, segment ref, video ref, metadata |
| `node` | OCR bounding boxes: text, position, size per frame |
| `video` | Video file metadata: path, frame count, start/end time, dimensions |
| `searchRanking` | FTS5 virtual table for full-text search |
| `searchRanking_content` | Backing content table for FTS5 |
| `doc_segment` | Linking table between frames and search index |
| `videoFileState` | Tracks video file encoding/finalization state |
| `schema_migrations` | Applied migration version tracking |

The database uses WAL mode, NORMAL synchronous, and auto-vacuum INCREMENTAL. Default location is **`~/Library/Application Support/Retrace/retrace.db`** next to the default storage root; users can relocate data via settings (`customRetraceDBLocation` in the `io.retrace.app` suite), in which case **`retrace.db` and `chunks/` should stay in the same chosen folder** so paths resolve consistently.

**Optional encryption:** When enabled, `DatabaseManager` applies a SQLCipher `PRAGMA key` using a secret stored in the Keychain (`AppPaths.keychainService` / `AppPaths.keychainAccount`). Unencrypted databases omit the pragma so standard SQLite tooling can open them.

---

## External Dependencies

### Swift Packages (via SPM)

| Package | Version | Purpose |
|---|---|---|
| [swift-sqlcipher](https://github.com/skiptools/swift-sqlcipher) | 1.0.0+ | SQLite with encryption; used for Rewind import and optional DB encryption |
| [Sparkle](https://github.com/sparkle-project/Sparkle) | 2.6.0+ | Auto-update framework for distributing new versions |
| [SwiftyChrono](https://github.com/batmac/SwiftyChrono) | pinned revision | Natural-language date parsing in the UI target |

### Apple System Frameworks

| Framework | Used by | Purpose |
|---|---|---|
| CoreGraphics | Capture | CGWindowList-based screen capture (`CGWindowListCapture`) |
| Vision | Processing | On-device OCR text extraction |
| VideoToolbox | Storage | Hardware-accelerated HEVC encoding |
| CryptoKit | Database / storage | Cryptographic primitives for protected data where applicable |
| AppKit / SwiftUI | UI | macOS interface |
| Accessibility | Capture, Processing | App context and window metadata |

### Bundled (Future)

| Library | Path | Status |
|---|---|---|
| whisper.cpp | `Vendors/whisper/` | Bundled, disabled (Release 2: audio transcription) |
| llama.cpp | `Vendors/llama/` | Bundled, disabled (Release 2: semantic/vector search) |

---

## Security Model

- **Local-only** -- No network calls for core functionality. Data never leaves the device.
- **Encryption at rest** -- Optional **SQLCipher** for the SQLite database (Keychain-stored key) when the user enables encryption; CryptoKit and other platform crypto for related protected material.
- **Permission-gated** -- Screen Recording and Accessibility permissions required; app checks and prompts gracefully.
- **No telemetry** -- No analytics, crash reporting, or usage data sent anywhere.
- **Private window exclusion** -- Configurable per-app exclusion list; auto-detection of private browsing.
- **Parameterized SQL** -- All database queries use parameter binding to prevent injection.

See [SECURITY.md](SECURITY.md) for the full security policy.

---

## Performance Targets

| Metric | Target | Critical threshold |
|---|---|---|
| CPU usage | <20% single core | 50% |
| Memory usage | <1 GB | 2 GB |
| Search latency | <100 ms | 500 ms |
| OCR latency | <500 ms/frame | 2 s |
| Storage growth | ~15--20 GB/month | 50 GB/month |

Current status: HEVC encoding is working but not yet optimized (~50--70 GB/month). Optimization is planned.

---

## Build System

- **Primary**: Swift Package Manager (`Package.swift`). `swift build` / `swift test`.
- **Products**: `Retrace` (app executable), plus small **dev utilities** `TestMostRecentFrame` and `QueryRewindApps` under `Sources/` for local debugging and Rewind-database inspection (not part of the shipped UX).
- **Release**: XcodeGen (`project.yml`) generates an Xcode project for archive + code signing + notarization.
- **CI**: GitHub Actions on macOS 14 (Apple Silicon). See `.github/workflows/ci.yml`.
- **Distribution**: Sparkle auto-update framework; DMG packaging via `scripts/create-release.sh`.

---

## Further Reading

- [README.md](README.md) -- Project overview and quick start
- [QUICKSTART.md](QUICKSTART.md) -- Developer setup guide
- [CONTRIBUTING.md](CONTRIBUTING.md) -- Coding standards, TDD, PR process
- [AGENTS.md](AGENTS.md) -- AI agent coordination and module ownership
- [DIAGRAMS.md](DIAGRAMS.md) -- Visual architecture and data flow diagrams
- [DEBUGGING.md](DEBUGGING.md) -- Debug logging and troubleshooting
- [SECURITY.md](SECURITY.md) -- Security policy and practices
