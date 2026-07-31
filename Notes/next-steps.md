# Next Steps

## Recently Completed ✅

### Enhanced Boundary & Title Extraction
- Enhanced boundary detection for cleaner title extraction
- Technical vs. meaningful parentheses handling (preserve "Part 1", drop "720p")
- Case-insensitive release group removal
- Subtitle support with language code preservation
- Multiple output formats via `--format` flag
- Anime mode with fansub pattern support

### MP4 Metadata Deep-Clean
- Deep-clean mode removes technical metadata from MP4/MKV containers
- Companion file renaming for subtitles and sidecars
- Automated Python testing infrastructure
- Enhanced verbose logging for debugging

### Leading-Number-With-Season Pattern ✅
- Added `PATTERN_LEADING_NUMBER_WITH_SEASON` to `parser.py` for filenames like `01. HORRIBLE_HISTORIES-S1.mp4`
- Leading number is the episode, trailing `-S#` or `_S#` tag is the season
- Checked before SxxExx/NxNN/E## so the leading number wins; `(?![Ee]?\d)` guard prevents hijacking genuine SxxExx codes
- Verified against real-world Horrible Histories (2009) — all 37 files across 3 seasons parsed correctly
- Known source-file edge case: `09. Horrible Histories-S2.mp4` sits in the Season 3 folder but its filename says S2 — parser faithfully follows the filename; fix the source file before applying

### Filesystem Test Coverage ✅
- Added `Tests/test_operations.py` with 27 tests covering the parts that actually touch disk
- `TestSafeRename`: dry-run, actual move, missing source, collision skip/force, already-correct no-op
- `TestRenameCompanions`: srt follows video, language codes preserved, non-companion ignored, dry-run, multiple companions
- `TestBuildFilename`: all `OutputFormat` variants, year-stripped vs. year-included, dual-episode, extension preservation
- `TestProcessVideoFile`: new leading-number pattern end-to-end, standard SxxExx still works, unparseable → failure, Specials → S00, dry-run creates no files
- `TestProcessDirectory`: batch processing, mixed parseable/unparseable, dry-run filesystem safety, files across season subdirs
- Test suite now 94 tests (was 59 before this branch)

### Python Migration ✅
- Full rewrite from ~1,300 line bash script to ~800 line Python package
- Clean module separation: `parser`, `cleaner`, `operations`, `metadata`, `cli`
- Dataclass-based structured types throughout (`RenameResult`, `RenameOptions`, `RenameSession`, etc.)
- Dry-run threaded end-to-end through all operations including metadata cleaning
- Callback architecture (`on_result`, `on_verbose`) decouples logic from CLI presentation
- Two-step case-only rename for case-insensitive filesystems (Windows/macOS)
- Specials folder → Season 00 detection
- Companion file renaming preserves language codes
- Ellipsis preservation via placeholder technique
- pytest test suite covering parser patterns and title cleaning pipeline

---

## Known Issues & Near-Term Fixes 🔧

### Release Group Detection Gap
- Current `RELEASE_GROUP_PATTERN` only matches ALL-CAPS or digit-containing groups
- Mixed-case release tags (e.g. `Ehhhh`) slip through and can become the extracted episode title
- Fix: widen the pattern or add a duplicate-title detection pass as a safety net

### Duplicate Title Detection
- If cleaning fails on a batch, multiple episodes can end up with identical titles (a reliable signal something went wrong)
- A post-processing check — "if N% of episodes in a batch have the same non-empty title, warn the user" — would catch any cleaning failure, not just the release group case
- Low effort, high value as a defensive layer regardless of other improvements

### Minor Code Issues
- `get_episode_title` in `operations.py` duplicates episode-stripping regex from `parser.py` — maintenance trap if new patterns are added (hit this already: leading-number pattern strips nothing in title cleanup)
- `renamed_count = [0]` closure workaround in `cli.py` should use `nonlocal`
- `Colors.disable()` mutates class-level state — breaks if `main()` is called more than once in the same process
- `build_filename` re-runs `detect_series_name_no_year()` on every file call; should be resolved once at session start
- `clean_mp4_metadata` temp file not in a `try/finally` — leaks on unexpected exception
- `result_callback` in `cli.py` is 40+ lines of orchestration logic that belongs in `operations.py`

---

## Future Enhancements

### API Integration (Optional, Opt-In)
- External episode database lookup (TVDB, TMDB, TVMaze) to validate and fill in missing episode titles
- Use S01E01 codes — the part that already works reliably — as the lookup key; stop relying on filename title parsing for well-known shows
- Ship with a `.env.example` file documenting available keys; users who want API features populate their own `.env`
- Graceful fallback to filename parsing when no key is configured or the show isn't found
- Suggested priority: TVDB (best TV coverage) with TMDB as secondary

### Multi-Episode File Support
- Filenames like `S01E01E02` and `S01E01-E02` are common and currently only capture the first episode
- Output should reflect both (e.g. `Show - S01E01-E02 - Title.mkv`)

### Interactive Mode
- Manual review for edge cases — show proposed rename, allow user to approve, edit, or skip
- Particularly useful when title extraction produces a suspicious result (empty, duplicate, matches series name)

### Configuration System
- `.renamerrc` or `renamer.toml` for default preferences (default format, default series name, anime mode, etc.)
- Per-directory overrides so different library folders can have different defaults
- Project-specific naming schemes

### Quality of Life
- Undo functionality via operation log (JSON file written alongside each run)
- Progress bars for large batches
- Parallel processing for metadata cleaning (the slow part)
- Resume capability for interrupted operations

---

## Key Principle

**The goal:** Transform from "I hope this works" to "I know this works because tests prove it."

The Python migration built that foundation. Future work should stay test-driven — every new feature or regex change should come with a test case that would have caught the original bug.
