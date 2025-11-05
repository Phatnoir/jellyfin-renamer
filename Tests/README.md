# Tests

Automated verification scripts for rename.sh features.

## Test Scripts

### `test_deep_clean_mp4.py`
Validates the `--deep-clean` flag's MP4 metadata cleaning functionality. Creates a test MP4 with dirty metadata, runs the deep-clean process, and verifies metadata was properly cleaned.

**Run:** `python3 test_deep_clean_mp4.py`

### `test_episode_pattern_detection.py`
Lightweight framework for verifying episode pattern detection. Creates dummy files with various naming formats, runs rename.sh in dry-run mode, and confirms patterns are correctly identified.

**Run:** `python3 test_episode_pattern_detection.py`

Currently tests:
- Standard patterns: `S01E01`, `1x01`, `E##`
- Anime patterns: `[Group] Show - ##`
- Edge cases: mixed case, junk metadata

**Adding new patterns:** Simply add tuples to the `test_cases` list with `(filename, expected_output, description)`.