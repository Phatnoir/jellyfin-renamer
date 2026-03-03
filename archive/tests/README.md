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

### `test_web_and_ellipsis.py`
Verifies that the word "Web" in episode titles is preserved while technical WEB tags are stripped, and that ellipses (...) are not destroyed during title cleaning.

**Run:** `python3 test_web_and_ellipsis.py`

Currently tests:
- WEB word preservation: "Tangled Web We Weaved", "Charlotte's Web", "Webmaster", etc.
- WEB tag stripping: `.WEB.x264`, `.WEB-DL`, `.WEBRip`, `.AMZN.WEB-DL`
- Leading ellipsis: "... And Girlfriends"
- Trailing ellipsis: "George...", "Sin... (1)"