# Tests

Integration and unit tests for the `renamer` Python package using pytest.

## Running Tests

```bash
# Run all tests
pytest Tests/

# Verbose output (shows each test name and pass/fail)
pytest Tests/ -v

# Run a specific test file
pytest Tests/test_parser.py
pytest Tests/test_operations.py

# Run with coverage
pytest Tests/ --cov=renamer
```

## Test Files

### `test_parser.py`
Tests for `renamer/parser.py` — regex pattern detection and episode info formatting.

- `TestStandardSxxExx` — S01E01, S1E1, separators between S and E
- `TestNxNNFormat` — 1x01, 01x05 style
- `TestSingleSeasonEPattern` — E01, E001 (defaults to season 1)
- `TestAnimeFansub` — `[Group] Show - 01 [Quality]` with and without `--anime`
- `TestLeadingNumberWithSeason` — `01. Show-S1.mp4` style; cases loaded from `fixtures/filenames.json`
- `TestNoMatch` — filenames that should return None
- `TestEpisodeInfoFormatting` — `format_code()` output for standard and dual-episode codes
- `TestNormalizeText` — text normalization for series name comparison

### `test_operations.py`
Filesystem integration tests for `renamer/operations.py` — the parts that actually touch disk. Uses pytest's `tmp_path` fixture to create real files and verify filesystem state after each operation.

- `TestSafeRename` — dry-run no-op, actual move, missing source, collision skip vs. force-overwrite, already-correct skip
- `TestRenameCompanions` — subtitle follows video, language codes preserved (`.en.srt`), non-companion extensions ignored, dry-run safety, multiple companions
- `TestBuildFilename` — all `OutputFormat` variants, year-stripped vs. year-included series name, dual-episode codes, extension passthrough
- `TestProcessVideoFile` — end-to-end: parser → rename, Specials folder → S00 override, unparseable → failure result, dry-run creates no files
- `TestProcessDirectory` — batch processing, mixed parseable/unparseable, dry-run filesystem safety, files across season subdirectories

### `test_cleaner.py`
Tests for `renamer/cleaner.py` — episode title extraction and cleaning.

- `TestTitleCleaning` — quality tags, codec strings, release group removal
- `TestFullTransformation` — end-to-end filename → cleaned output
- `TestEdgeCases` — ellipsis preservation, Part numbers, WEB in title

## Test Fixtures

`fixtures/filenames.json` is a corpus of filename patterns organized by category:

- `episode_patterns` — S01E01, 1x01, E##, anime, leading-number-with-season, no-match cases
- `title_cleaning` — quality boundary detection, technical tag removal, meaningful text preservation
- `series_detection` — extracting series names from folder structures

The `leading_number_with_season` section is loaded directly by `TestLeadingNumberWithSeason` in `test_parser.py` via a helper — adding a case there automatically adds a test. The other sections currently serve as a documented reference corpus; tests for those patterns use inline `@pytest.mark.parametrize` data.

## Adding Tests

**New parser pattern** — add cases to the appropriate section in `fixtures/filenames.json`, then add or extend a test class in `test_parser.py` using `@pytest.mark.parametrize`.

**New filesystem behavior** — add a test to `test_operations.py` using `tmp_path`. The pattern is: create real files with `touch()` or `write_text()`, call the function, assert on both the return value and the filesystem state.

**New title cleaning rule** — add cases to `test_cleaner.py` following the existing parametrize patterns there.
