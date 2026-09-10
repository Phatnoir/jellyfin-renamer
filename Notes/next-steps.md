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
- Added `Tests/test_operations.py` with tests covering the parts that actually touch disk
- `TestSafeRename`: dry-run, actual move, missing source, collision skip/force, already-correct no-op
- `TestRenameCompanions`: srt follows video, language codes preserved, non-companion ignored, dry-run, companion collision preservation
- `TestBuildFilename`: all `OutputFormat` variants, year-stripped vs. year-included, dual-episode, extension preservation
- `TestProcessVideoFile`: new leading-number pattern end-to-end, standard SxxExx still works, unparseable → failure, Specials → S00, dry-run creates no files
- `TestProcessDirectory`: batch processing, mixed parseable/unparseable, dry-run filesystem safety, actual non-dry-run rename with companions, batch collision skipping, files across season subdirs
- Corpus is now the single source of truth — `test_parser.py` loads all data-driven cases from `filenames.json` at collection time; adding a JSON row adds a test
- `TestSeriesDetection` added to cover `detect_series_name()` against the series_detection corpus sections
- Test suite now 105 tests (was 59 before this branch)

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

### `--force` Does Not Apply to Companion Files (Policy Undefined)
- `process_video_file` passes `force=session.options.force` when renaming the video, but calls `rename_companions()` without it
- `rename_companions()` has no `force` parameter and always calls `safe_rename(..., force=False)`
- Result: with `--force`, an existing destination video is overwritten, but an existing destination subtitle or NFO is silently preserved as a skipped collision
- The CLI describes `--force` as "overwrite existing files" with no qualifier — this is surprising behaviour
- **Two valid policies, pick one before shipping:**
  - **Policy A (force applies to companions):** add `force: bool = False` to `rename_companions()`, thread `session.options.force` through the call in `process_video_file`, add a test proving `force=True` overwrites an existing sidecar
  - **Policy B (companions never forcibly overwritten):** document the intentional asymmetry, update the `--force` help text, add a test proving `force=True` still preserves an existing sidecar

### Silent Companion Failure (Strongest Remaining Concern)
- When a companion rename fails (e.g. destination sidecar already exists), `process_video_file` logs it verbosely but does not surface it to the caller
- The video result is reported as `success=True`; the companion failure is not added to `session.results` and the `on_result` callback is never called for it
- Net effect: a batch can silently complete with a renamed video and an un-renamed subtitle, and the summary shows no errors
- **Minimum fix:** call `session.options.on_result(comp_result)` for failed companion results inside `process_video_file` so CLI output and callers see the failure
- Whether companion results belong in `session.results` / the `process_directory` return value is a separate API decision, but silent failures should not be the default
- The existing `test_companion_collision_without_force_preserves_existing` test confirms the low-level collision behaviour; a batch-level test asserting that a companion failure appears in output or results does not yet exist

### `--force` Overwrite Silently Broken on Windows
- `safe_rename()` in `operations.py` overwrites an existing destination via `old_path.rename(new_path)` — same call used for the non-collision case, with nothing force-specific happening for the overwrite itself
- `Path.rename()` wraps `os.rename()`, which silently overwrites the destination on POSIX but raises `FileExistsError` on Windows (`MoveFileExW` without `MOVEFILE_REPLACE_EXISTING`)
- Net effect: `force=True` works on Linux/macOS by accident of platform semantics, but on Windows the rename fails and `safe_rename()` returns `success=False`
- Confirmed via `test_collision_with_force_overwrites` in `Tests/test_operations.py`, which fails on Windows and passes on POSIX
- Fix: use `os.replace()` instead of `.rename()` when overwriting (documented atomic-overwrite behavior on both platforms), or explicitly `os.remove(new_path)` before the rename

### Release Group Detection Gap
- Current `RELEASE_GROUP_PATTERN` only matches ALL-CAPS or digit-containing groups
- Mixed-case release tags (e.g. `Ehhhh`) slip through and can become the extracted episode title
- Fix: widen the pattern or add a duplicate-title detection pass as a safety net

### Duplicate Title Detection
- If cleaning fails on a batch, multiple episodes can end up with identical titles (a reliable signal something went wrong)
- A post-processing check — "if N% of episodes in a batch have the same non-empty title, warn the user" — would catch any cleaning failure, not just the release group case
- Low effort, high value as a defensive layer regardless of other improvements

### `conftest.py` Fixtures Are Unused
- `conftest.py` defines `test_corpus`, `episode_patterns`, `title_cleaning_cases`, and `series_detection_cases` fixtures, but none of the current test files use them
- `test_parser.py` loads JSON directly at module level (required for parametrize collection time); pytest fixtures cannot supply collection-time parameter data, so the fixtures can never replace this
- Options: remove the unused fixtures to eliminate the confusion, or keep them for any future non-parametrized tests that need corpus data
- Minor: `conftest.py` opens the JSON without `encoding="utf-8"` while `test_parser.py` correctly specifies it — inconsistent if filenames with non-ASCII characters are ever added to the corpus

### `cli.py` and `metadata.py` Have No Tests
- Two substantial modules are completely untested: `cli.py` (~150 lines, argument parsing and output formatting) and `metadata.py` (external subprocess invocation for MKV/MP4 cleaning)
- `metadata.py` is the highest-risk untested code — it invokes `mkvpropedit`, `mkvmerge`, `ffmpeg`, and `mediainfo`; handles temp files; and has more failure branches than the rename logic
- High-value `metadata.py` tests (would require mocking subprocess): missing external tools, dry-run never invokes a mutating command, nonzero exit status preserves the original file, temp file is cleaned up on failure, already-clean file is not unnecessarily remuxed
- High-value `cli.py` tests (calling `main([...])` directly): invalid directory returns exit code 1, anime mode changes default format but not an explicitly supplied format, `--force` and `--dry-run` reach `RenameOptions`, exit status reflects failures

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
