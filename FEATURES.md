# Fork and community feature tracker

Human-maintained registry for **interesting fork work** (often without an upstream PR yet), local **tracking branches**, and whether pieces landed in **`develop`** or **upstream `main`**.

Upstream hub: [haseab/retrace](https://github.com/haseab/retrace) · [Pull requests](https://github.com/haseab/retrace/pulls?q=is%3Apr+) · [Forks](https://github.com/haseab/retrace/forks).

Refresh local GitHub JSON cache and auto-generated contributor notes (gitignored):

```sh
./scripts/github_export_upstream.sh
./scripts/github_summarize_contributors.sh
# See research/github-haseab/contributors-summary.md
```

Start tracking a fork tip in git (adds `fork-<owner>` remote + `track/<owner>-<branch>`):

```sh
./scripts/fork_track_remote.sh stuartsc main
```

## Status values

| Status | Meaning |
|--------|---------|
| `not_tried` | Not fetched / not reviewed |
| `branch_only` | `track/...` exists locally, not merged into `develop` |
| `in_develop` | Merged or cherry-picked into your `develop` |
| `pr_upstream` | PR opened to haseab/retrace |
| `merged_upstream` | Landed on haseab/retrace `main` |
| `rejected` | Reviewed; intentionally not taking |

## Registry

| id | source | focus (short) | compare URL | local branch | last_fetch | status | develop | upstream |
|----|--------|---------------|--------------|--------------|------------|--------|---------|----------|
| fork-stuartsc | [stuartsc/retrace](https://github.com/stuartsc/retrace) | Audio pipeline, transcript UI, whisper (see fork commits) | [compare main...stuartsc:main](https://github.com/haseab/retrace/compare/main...stuartsc:retrace:main) | `track/stuartsc-main` (after script) | | `not_tried` | | |
| fork-runprise | [runprise/retrace](https://github.com/runprise/retrace) | Docs map, audio pipeline, ContextFeed | [compare main...runprise:main](https://github.com/haseab/retrace/compare/main...runprise:retrace:main) | `track/runprise-main` (after script) | | `not_tried` | | |
| fork-ocean | [ocean/retrace](https://github.com/ocean/retrace) | (fill after review) | [compare main...ocean:main](https://github.com/haseab/retrace/compare/main...ocean:retrace:main) | | | `not_tried` | | |

_Add rows as you discover useful forks; update `last_fetch` and `status` when you integrate or discard._

## Inspect a tracking branch

```sh
git fetch fork-stuartsc
git log upstream/main..track/stuartsc-main --oneline
```

Merge into `develop` only after you are happy with scope and tests:

```sh
git checkout develop
git merge --no-ff track/stuartsc-main   # or cherry-pick subset
```
