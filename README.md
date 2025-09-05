# Universal Media Renamer for Jellyfin/Plex

A smart, cross-platform Bash script that renames TV show files so they work perfectly with Jellyfin, Plex, and other media servers — without breaking your existing structure.

> ⚠️ **Disclaimer**  
> This script is under active development.  
> Always use `--dry-run` first and test on backups or small batches.  
> Pull requests, feedback, and issues are welcome!

---

## Recent Improvements

* **NEW**: Added anime/fansub support with `--anime` flag
* **NEW**: Support for anime naming patterns like `[Group] Show - 01 [Quality]`
* Enhanced episode title extraction using quality/source boundary detection
* Improved technical metadata removal with precise pattern matching
* More robust handling of complex filename structures
* Better series name cleaning and normalization
* Added subtitle file support with language code preservation

---

## Quick Start (TL;DR)

```bash
# Make executable
chmod +x rename.sh

# Preview renames (safe)
./rename.sh --dry-run "/path/to/TV Shows/Breaking Bad (2008)"

# For anime/fansub releases
./rename.sh --anime --dry-run "/path/to/Anime/Cyberpunk Edgerunners (2022)"

# Apply renames (once you're happy)
./rename.sh "/path/to/TV Shows/Breaking Bad (2008)"
```

---

## Features

* **Dual Format Support**: Standard TV shows AND anime/fansub releases
* Detects multiple episode naming patterns (`S01E01`, `1x01`, `- 01 [Quality]`)
* Extracts series names from folder structure automatically
* Separates episode titles from technical metadata via boundary detection
* Strips codec info, quality tags, and release group names with precision
* Supports multiple output formats, including year preservation
* Works on Linux, macOS, and Windows (via WSL)
* Renames subtitle files to match episode names
* Runs safely with dry-run mode and validation checks

---

## Supported Episode Patterns

### Standard TV Shows
- `S01E01`, `S1E1` - Standard season/episode format
- `1x01`, `01x01` - Alternative season x episode format

### Anime/Fansub Releases
- `[Group] Show - 01 [Quality]` - Common fansub format
- `Show - 01 [Metadata]` - Simplified anime format
- Works with groups like `[Erai-raws]`, `[SubsPlease]`, `[HorribleSubs]`, etc.

---

## Supported File Types

| Type      | Extensions                                        |
| --------- | ------------------------------------------------- |
| **Video** | mkv, mp4, avi, m4v, mov, wmv, flv, webm, ts, m2ts |
| **Subs**  | srt, sub, ass, ssa, vtt                           |

---

## Folder Structure Requirements

**IMPORTANT**: This script works best with properly organized TV show folders. Each show should have its own folder:

### Recommended Structure (Standard TV)
```
TV Shows/
├── Breaking Bad (2008)/
│   ├── Season 1/
│   │   ├── Breaking.Bad.S01E01.Pilot.720p.WEB-DL.x264-GROUP.mkv
│   │   └── Breaking.Bad.S01E02.Cat's.in.the.Bag.720p.WEB-DL.x264-GROUP.mkv
│   └── Season 2/
│       └── episode files...
├── Doctor Who (2005)/
│   ├── Season 5/
│   │   └── Doctor.Who.2005.S05E04.Time.Of.The.Angels.HDTV.XviD-FoV.avi
│   └── Specials/
│       └── special episode files...
└── 3 Body Problem (2024)/
    └── Season 1/
        └── episode files...
```

### Anime Structure
```
Anime/
├── Cyberpunk Edgerunners (2022)/
│   ├── [Erai-raws] Cyberpunk - Edgerunners - 01 [1080p][Multiple Subtitle].mkv
│   ├── [Erai-raws] Cyberpunk - Edgerunners - 02 [1080p][Multiple Subtitle].mkv
│   └── [Erai-raws] Cyberpunk - Edgerunners - 03 [1080p][Multiple Subtitle].mkv
└── Attack on Titan (2013)/
    ├── [SubsPlease] Attack on Titan - 01 [1080p].mkv
    └── [SubsPlease] Attack on Titan - 02 [1080p].mkv
```

### Also Works (Show folder without season subfolders)
```
TV Shows/
├── Breaking Bad (2008)/
│   ├── Breaking.Bad.S01E01.Pilot.720p.WEB-DL.x264-GROUP.mkv
│   └── Breaking.Bad.S01E02.Cat's.in.the.Bag.720p.WEB-DL.x264-GROUP.mkv
└── Doctor Who (2005)/
    └── Doctor.Who.2005.S05E04.Time.Of.The.Angels.HDTV.XviD-FoV.avi
```

### ⚠️ What NOT to do (Mixed shows in one folder)
```
Mixed Folder/  ← Script will think "Mixed Folder" is the series name!
├── Breaking.Bad.S01E01.mkv  ← Will become "Mixed Folder - S01E01.mkv"
├── Doctor.Who.S05E04.avi    ← Will become "Mixed Folder - S05E04.avi"
└── 3.Body.Problem.S01E01.mkv ← Will become "Mixed Folder - S01E01.mkv"
```

---

## Usage Examples

### Basic Usage
```bash
# Process a single show folder (recommended)
./rename.sh --dry-run "/path/to/TV Shows/Breaking Bad (2008)"

# Process current directory (if you're in a show folder)
./rename.sh --dry-run .

# Process all shows with proper folder structure
for show in "/path/to/TV Shows"/*; do
    ./rename.sh --dry-run "$show"
done
```

### Anime/Fansub Usage
```bash
# Process anime with anime mode (prioritizes anime patterns)
./rename.sh --anime --dry-run "/path/to/Anime/Cyberpunk Edgerunners (2022)"

# Anime with custom format
./rename.sh --anime --format "Show - SxxExx" --dry-run "/path/to/anime"

# Anime with series name override
./rename.sh --anime --series "Attack on Titan" --dry-run "/path/to/aot-folder"
```

### With Series Name Override
```bash
# Manually specify series name
./rename.sh --series "Breaking Bad" --dry-run "/path/to/breaking-bad"

# For shows with complex names
./rename.sh --series "My Little Pony Friendship Is Magic" --dry-run "/path/to/mlp"
```

### Different Output Formats
```bash
# Show with year (recommended)
./rename.sh --format "Show (Year) - SxxExx" --dry-run .

# Show without year
./rename.sh --format "Show - SxxExx" --dry-run .

# Just episode codes
./rename.sh --format "SxxExx" --dry-run .

# Include episode titles (when available)
./rename.sh --format "Show - SxxExx - Title" --dry-run .
```

### Advanced Options
```bash
# Verbose output for debugging
./rename.sh --verbose --dry-run .

# Force overwrite existing files (use with caution)
./rename.sh --force .

# Combine options
./rename.sh --anime --format "Show - SxxExx" --verbose --dry-run "/path/to/anime"
```

---

## Command Line Options

| Option            | Description                                 |
| ----------------- | ------------------------------------------- |
| `--dry-run`       | Preview changes without making them         |
| `--verbose`       | Show detailed processing information        |
| `--force`         | Overwrite existing files (use with caution) |
| `--anime`         | Enable anime/fansub mode (prioritizes anime patterns) |
| `--series "Name"` | Manually specify series name                |
| `--format FORMAT` | Choose output format (see formats below)   |
| `--help`, `-h`    | Show help message                           |

---

## Output Formats

### `Show (Year) - SxxExx` (Recommended)
```
3 Body Problem (2024) - S01E01.mkv
Breaking Bad (2008) - S01E02.mkv
```

### `Show - SxxExx`
```
3 Body Problem - S01E01.mkv
Breaking Bad - S01E02.mkv
Cyberpunk Edgerunners - S01E01.mkv  # Good for anime
```

### `Show - SxxExx - Title`
```
Breaking Bad - S01E01 - Pilot.mkv
Breaking Bad - S01E02 - Cat's in the Bag.mkv
```

### `SxxExx - Title`
```
S01E01 - Pilot.mkv
S01E02 - Cat's in the Bag.mkv
```

### `SxxExx`
```
S01E01.mkv
S01E02.mkv
```

---

## What It Does

### Before (Standard TV - properly organized folder)
```
Breaking Bad (2008)/
├── Season 1/
│   ├── Breaking.Bad.S01E01.Pilot.720p.WEB-DL.x264-GROUP.mkv
│   └── Breaking.Bad.S01E02.Cat's.in.the.Bag.720p.WEB-DL.x264-GROUP.mkv
└── Season 2/
    └── Breaking.Bad.S02E01.Seven.Thirty-Seven.720p.WEB-DL.x264-GROUP.mkv
```

### After (using `--format "Show (Year) - SxxExx"`)
```
Breaking Bad (2008)/
├── Season 1/
│   ├── Breaking Bad (2008) - S01E01.mkv
│   └── Breaking Bad (2008) - S01E02.mkv
└── Season 2/
    └── Breaking Bad (2008) - S02E01.mkv
```

### Before (Anime/Fansub)
```
Cyberpunk Edgerunners (2022)/
├── [Erai-raws] Cyberpunk - Edgerunners - 01 [1080p][Multiple Subtitle][ABC123].mkv
├── [Erai-raws] Cyberpunk - Edgerunners - 02 [1080p][Multiple Subtitle][DEF456].mkv
└── [Erai-raws] Cyberpunk - Edgerunners - 03 [1080p][Multiple Subtitle][GHI789].mkv
```

### After (using `--anime --format "Show - SxxExx"`)
```
Cyberpunk Edgerunners (2022)/
├── Cyberpunk Edgerunners - S01E01.mkv
├── Cyberpunk Edgerunners - S01E02.mkv
└── Cyberpunk Edgerunners - S01E03.mkv
```

### With Episode Titles (using `--format "Show - SxxExx - Title"`)
```
Breaking Bad (2008)/
├── Season 1/
│   ├── Breaking Bad - S01E01 - Pilot.mkv
│   └── Breaking Bad - S01E02 - Cat's in the Bag.mkv
└── Season 2/
    └── Breaking Bad - S02E01 - Seven Thirty-Seven.mkv
```

---

## Auto-Detection Features

The script automatically:

- **Detects series name** from folder structure (e.g., "3 Body Problem (2024)" → "3 Body Problem")
- **Preserves years** when using appropriate formats
- **Recognizes episode patterns**: `S01E01`, `S1E1`, `1x01`, `01x01`, `- 01 [Quality]`
- **Handles anime/fansub formats**: Detects `[Group] Show - Episode [Metadata]` patterns
- **Intelligently extracts episode titles** using boundary detection to separate titles from technical metadata
- **Cleans filenames** by removing:
  - Quality indicators (720p, 1080p, 4K, etc.)
  - Codec info (x264, x265, HEVC, H264)
  - Source tags (WEB, WEB-DL, BluRay, BDRip, HDTV)
  - Audio info (AAC, AC3, DTS)
  - Platform tags (AMZN, NFLX, HULU, etc.)
  - Release group names and fansub group tags
  - Hash codes in anime releases (like `[ABC123]`)

---

## Anime Mode (`--anime`)

When you use the `--anime` flag, the script:

- **Prioritizes anime patterns** like `- 01 [Quality]` over standard TV patterns
- **Defaults season to 01** for single-season anime shows
- **Changes default format** to `"Show - SxxExx"` (no episode titles, cleaner for anime)
- **Handles fansub groups** like `[Erai-raws]`, `[SubsPlease]`, `[HorribleSubs]`
- **Removes hash codes** and complex metadata brackets
- **Works with various anime naming conventions**

### When to Use Anime Mode

Use `--anime` when processing:
- Fansub releases with `[Group]` tags
- Files with `- 01 [Quality]` episode numbering
- Anime that doesn't follow standard `S01E01` patterns
- Shows where you want cleaner, episode-title-free naming

---

## Title Extraction Intelligence

The script uses advanced parsing to cleanly extract episode titles:

- **Boundary Detection**: Identifies where technical metadata begins (e.g., at quality indicators like "720p")
- **Anime-Aware Parsing**: Handles bracket structures in fansub releases
- **Smart Cleaning**: Removes series names, years, and technical tags while preserving actual episode titles
- **Edge Case Handling**: Properly handles parentheses, brackets, and complex filename structures
- **Fallback Logic**: When clean titles can't be extracted, falls back to episode codes only

---

## Safety Features

- **Idempotent**: Safe to run multiple times
- **Validation**: Checks file existence and prevents overwrites
- **Dry-run**: Preview all changes before applying
- **Backup-friendly**: Original files only moved, not copied
- **Error handling**: Graceful failure with detailed error messages
- **Subtitle preservation**: Maintains language codes in subtitle files

---

## Troubleshooting

### No files found
- Check file extensions are supported (mkv, mp4, avi, etc.)
- Verify the path is correct
- Use `--verbose` to see what the script is detecting

### Episode patterns not detected (anime)
- **Try `--anime` flag** for fansub releases
- Check that files follow supported patterns (`- 01 [Quality]`)
- Use `--verbose` to see which patterns are being tested
- For unusual formats, consider `--series` override

### Series name not detected correctly
- **Ensure proper folder structure**: Each show should have its own folder
- Use `--series "Exact Series Name"` to override auto-detection
- Check that the folder name contains the series name (e.g., "Breaking Bad (2008)")
- Use `--verbose` to see detection process
- Avoid mixing multiple shows in one folder

### Episode titles not clean
- The script now uses improved boundary detection for cleaner titles
- Use `--format "Show - SxxExx"` to avoid including titles if they're still problematic
- Consider manually specifying `--series` for better cleaning
- For anime, try `--anime` flag which defaults to no episode titles

### Permission errors
- Ensure you have write permissions to the directory
- On WSL, check Windows file permissions
- Try running with appropriate user privileges

---

## Examples by Show Type

### Standard TV Show
```bash
./rename.sh --format "Show (Year) - SxxExx" --dry-run "/path/to/office"
```

### Anime (with anime mode)
```bash
./rename.sh --anime --dry-run "/path/to/anime/show"
./rename.sh --anime --format "Show - SxxExx" --series "Attack on Titan" --dry-run "/path/to/aot"
```

### Shows with episode titles
```bash
./rename.sh --format "Show - SxxExx - Title" --dry-run "/path/to/show-with-good-titles"
```

### Clean, minimal naming
```bash
./rename.sh --format "SxxExx" --dry-run "/path/to/shows"
```

---

## Tips

1. **Always use `--dry-run` first** to preview changes
2. **Organize shows properly**: Each show should have its own folder before running the script
3. **Use `--anime` for fansub releases** and anime with non-standard naming
4. **Use `--verbose`** when troubleshooting or understanding the parsing process
5. **Start with `"Show (Year) - SxxExx"` format** for TV shows - it's the most compatible
6. **Use `"Show - SxxExx"` format for anime** - cleaner and more appropriate
7. **Specify `--series`** if auto-detection isn't working well
8. **Process shows individually** rather than running on a mixed folder
9. **Make backups** of important collections before running
10. **Test on a small subset** before processing large collections
11. **Episode titles work best** with files that have clear technical metadata boundaries

---

## Requirements

- Bash 4.0+ (most modern systems)
- Standard Unix tools (`find`, `sed`, etc.)
- Write permissions to target directories

---

## License

This script is provided as-is for personal use. Feel free to modify and distribute.