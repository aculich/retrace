# Diagrams

Visual diagrams of Retrace's architecture, data flow, database schema, and module dependencies. All diagrams use [Mermaid](https://mermaid.js.org/) syntax and render natively on GitHub.

---

## High-Level Architecture

```mermaid
flowchart TB
  subgraph ui [UI Layer]
    RetraceApp[RetraceApp]
    Views[Views and ViewModels]
    Components[MenuBar, Hotkeys, Theme]
  end

  subgraph app [App Coordination]
    AppCoord[AppCoordinator]
    ServiceCont[ServiceContainer]
    DataAdapt[DataAdapter]
  end

  subgraph features [Feature Modules]
    Capture[Capture]
    Processing[Processing]
    Search[Search]
    Migration[Migration]
  end

  subgraph storage [Storage Layer]
    StorageMgr[Storage Manager]
    DB[(Database + FTS5)]
  end

  Shared[Shared: Protocols + Models]

  RetraceApp --> AppCoord
  Views --> DataAdapt
  Components --> AppCoord
  AppCoord --> ServiceCont
  ServiceCont --> Capture
  ServiceCont --> Processing
  ServiceCont --> Search
  ServiceCont --> Migration
  Capture --> StorageMgr
  Processing --> DB
  Search --> DB
  Migration --> DB
  StorageMgr --> Shared
  DB --> Shared
  Capture --> Shared
  Processing --> Shared
  Search --> Shared
  Migration --> Shared
```

---

## Capture and Processing Data Flow

```mermaid
flowchart LR
  CGCapture["CGWindowListCapture\n(every 2s)"]
  Dedup[FrameDeduplicator]
  OCR[VisionOCR]
  HEVC[HEVCEncoder]
  StoreDisk["Storage\n(.mp4 files)"]
  DBInsert["DatabaseManager\n(SQLite)"]
  FTS["FTSManager\n(FTS5 index)"]
  Ingest[IngestionManager]

  CGCapture --> Dedup
  Dedup -->|"~5% unique"| OCR
  Dedup -->|"~5% unique"| HEVC
  HEVC --> StoreDisk
  OCR -->|ExtractedText| DBInsert
  DBInsert --> Ingest
  Ingest --> FTS
```

---

## Search Pipeline

```mermaid
flowchart LR
  UserQuery["User query string"]
  Parser["QueryParser\n(app:, date:, -exclude)"]
  FTSSearch["FTSManager\n(FTS5 MATCH + BM25)"]
  Ranker["ResultRanker"]
  Results["SearchResult[]\n(frameId, snippet, highlight)"]
  SearchUI["SearchView / Timeline"]

  UserQuery --> Parser
  Parser --> FTSSearch
  FTSSearch --> Ranker
  Ranker --> Results
  Results --> SearchUI
```

---

## Database Entity Relationship

```mermaid
erDiagram
  segment {
    TEXT id PK
    TEXT app_bundle_id
    TEXT app_name
    TEXT window_title
    INTEGER start_time
    INTEGER end_time
  }
  frame {
    INTEGER id PK
    TEXT segment_id FK
    INTEGER video_id FK
    INTEGER timestamp
    INTEGER video_frame_index
    TEXT source
  }
  video {
    INTEGER id PK
    TEXT relative_path
    INTEGER frame_count
    INTEGER start_time
    INTEGER end_time
    INTEGER width
    INTEGER height
  }
  node {
    INTEGER id PK
    INTEGER frame_id FK
    TEXT text
    REAL x
    REAL y
    REAL width
    REAL height
  }
  searchRanking_content {
    INTEGER id PK
    INTEGER frame_id FK
    TEXT content
    TEXT app_name
    TEXT window_title
    INTEGER timestamp
  }
  doc_segment {
    INTEGER id PK
    INTEGER frame_id FK
    TEXT segment_id FK
  }

  segment ||--o{ frame : "contains"
  frame }o--|| video : "encoded in"
  frame ||--o{ node : "has OCR regions"
  frame ||--o| searchRanking_content : "indexed text"
  frame ||--o| doc_segment : "links to"
  doc_segment }o--|| segment : "references"
```

---

## Module Dependency Graph

All modules depend only on `Shared` (protocols and models). The `App` layer composes them. No module imports another module directly.

```mermaid
flowchart BT
  Shared[Shared]

  Database --> Shared
  Storage --> Shared
  Capture --> Shared
  Processing --> Shared
  Search --> Shared
  Migration --> Shared

  Processing -.->|"uses types"| Database
  App --> Database
  App --> Storage
  App --> Capture
  App --> Processing
  App --> Search
  App --> Migration

  UI --> App
  UI --> Shared
```

Note: Processing has a build-time dependency on Database (for `DatabaseManager` type), but communicates via `DatabaseProtocol` at runtime.

---

## Application Lifecycle

```mermaid
sequenceDiagram
  participant User
  participant RetraceApp
  participant AppCoord as AppCoordinator
  participant SC as ServiceContainer
  participant Cap as CaptureManager
  participant Proc as ProcessingManager
  participant DB as DatabaseManager

  User->>RetraceApp: Launch app
  RetraceApp->>AppCoord: initialize()
  AppCoord->>SC: create services
  SC->>DB: initialize() + run migrations
  SC->>Cap: initialize()
  SC->>Proc: initialize()
  AppCoord->>Cap: startCapture()

  loop Every 2 seconds
    Cap->>Cap: CGWindowListCapture
    Cap->>Cap: deduplicate (perceptual hash)
    Cap-->>Proc: new unique frame
    Cap-->>SC: encode to HEVC
    Proc->>Proc: VisionOCR
    Proc->>DB: insertFrame + indexText
  end

  User->>RetraceApp: Search query
  RetraceApp->>AppCoord: search(query)
  AppCoord->>DB: FTS5 MATCH
  DB-->>RetraceApp: SearchResult[]
  RetraceApp-->>User: Display results
```

---

## Storage Layout

```
~/Library/Application Support/Retrace/
  retrace.db              # SQLite database (FTS5, WAL mode)
  retrace.db-wal          # Write-ahead log
  retrace.db-shm          # Shared memory
  videos/
    2026/
      01/
        segment_abc123.mp4   # HEVC encoded screen recordings
        segment_def456.mp4
      02/
        ...
```

---

## UI Structure

```mermaid
flowchart TB
  RetraceApp --> ContentView
  ContentView --> MenuBarManager
  ContentView --> HotkeyManager

  subgraph windows [Windows]
    Timeline[TimelineWindowController]
    Dashboard[DashboardWindowController]
    SystemMon[SystemMonitorWindowController]
  end

  HotkeyManager -->|"Cmd+Shift+T"| Timeline
  HotkeyManager -->|"Cmd+Shift+D"| Dashboard

  Timeline --> SimpleTimelineView
  Timeline --> TimelineTapeView
  Timeline --> SpotlightSearchOverlay
  Timeline --> FullscreenFrameView

  Dashboard --> DashboardView
  Dashboard --> AppUsageListView
  Dashboard --> SystemMonitorView

  ContentView --> SettingsView
  ContentView --> OnboardingView
  ContentView --> FeedbackFormView
```

---

## Future: Audio and Vector Search (Release 2)

```mermaid
flowchart LR
  Mic["System Audio / Mic"]
  Whisper["whisper.cpp\n(local transcription)"]
  AudioDB["audio / transcript_word tables"]
  Llama["llama.cpp\n(local embeddings)"]
  VecStore["SQLiteVectorStore"]
  Hybrid["HybridSearchManager\n(FTS5 + vector)"]

  Mic --> Whisper
  Whisper --> AudioDB
  AudioDB --> Hybrid
  Processing -->|"ExtractedText"| Llama
  Llama --> VecStore
  VecStore --> Hybrid
```

These components are bundled in `Vendors/` but currently disabled.
