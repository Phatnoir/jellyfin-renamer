# Universal Media Renamer for Jellyfin/Plex

A smart, cross-platform Bash script that renames TV show files so they work perfectly with Jellyfin, Plex, and other media servers — without breaking your existing structure.

> ⚠️ **Disclaimer**  
> This script is under active development.  
> Always use `--dry-run` first and test on backups or small batches.  
> Pull requests, feedback, and issues are welcome!

---

## Recent Improvements

* **FIXED**: Sidecar file renaming now works reliably on case-insensitive filesystems (WSL/NTFS)
* **FIXED**: Subtitles no longer get renamed twice with different titles than their video files
* **FIXED**: Episode titles with hyphens (like "Ch-ch-changes") are now preserved correctly
* **FIXED**: Episode pattern matching now supports spaced formats like `S01 E01` in addition to `S01E01`
* **FIXED**: Subtitle files are no longer processed twice when using `--deep-clean`
* **IMPROVED**: Enhanced language code detection supports more formats (EN, pt-BR, forced, etc.)
* **IMPROVED**: Smart title validation prevents series name duplication and deduplication within seasons
* **IMPROVED**: Enhanced metadata cleaning for MP4 files (only processes files with problematic metadata)
* **IMPROVED**: Better handling of anime/fansub naming patterns with `--anime` flag
* **FEATURE**: Deep metadata cleanup with `--deep-clean` for MKV and MP4 files
* **FEATURE**: Automatic companion file renaming (subtitles, artwork, NFO files)
* **FEATURE**: MediaInfo fallback for extracting episode titles from container metadata
* **FEATURE**: Intelligent permission fixing for read-only files

---

## Quick Start (TL;DR)

```bash
# Make executable
chmod +x rename.sh

# Preview renames (safe)
./rename.sh --dry-run "/path/to/TV Shows/Breaking Bad (2008)"

# With metadata cleanup for MKV files
./rename.sh --deep-clean --dry-run "/path/to/TV Shows/Breaking Bad (2008)"

# For anime/fansub releases
./rename.sh --anime --dry-run "/path/to/Anime/Cyberpunk Edgerunners (2022)"

# Apply renames (once you're happy)
./rename.sh "/path/to/TV Shows/Breaking Bad (2008)"
```

---

## Features

* **Deep Metadata Cleanup**: Clean internal MKV container and track metadata with `--deep-clean`
* **Companion File Management**: Automatically renames subtitles, artwork, and NFO files to match videos
* **Intelligent Permission Handling**: Automatically fixes read-only file permissions when needed
* **Dual Format Support**: Standard TV shows AND anime/fansub releases
* **Flexible Episode Pattern Support**: Handles `S01E01`, `S01 E01`, `1x01`, `- 01 [Quality]` and more
* **Intelligent Title Extraction**: Uses boundary detection to separate episode titles from technical metadata
* **Smart Content Preservation**: Keeps meaningful content like "(Part 1)" while removing technical tags
* Detects series names from folder structure automatically
* Strips codec info, quality tags, and release group names with precision
* Supports multiple output formats, including year preservation
* Works on Linux, macOS, and Windows (via WSL)
* Renames subtitle files to match episode names with language code preservation
* Runs safely with dry-run mode and validation checks

---

## Supported Episode Patterns

### Standard TV Shows
- `S01E01`, `S1E1` - Standard season/episode format
- `S01 E01`, `S1 E1` - Spaced season/episode format
- `S01.E01`, `S01_E01`, `S01-E01` - Various separator formats
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
# Show with year (recommended for TV shows)
./rename.sh --format "Show (Year) - SxxExx" --dry-run .

# Show with year and episode titles
./rename.sh --format "Show (Year) - SxxExx - Title" --dry-run .

# Show without year (good for anime)
./rename.sh --format "Show - SxxExx" --dry-run .

# Just episode codes
./rename.sh --format "SxxExx" --dry-run .

# Include episode titles (when available)
./rename.sh --format "Show - SxxExx - Title" --dry-run .
```

### Advanced Options
```bash
# Deep metadata cleanup (cleans internal MKV metadata)
./rename.sh --deep-clean --dry-run .

# Verbose output for debugging
./rename.sh --verbose --dry-run .

# Force overwrite existing files (use with caution)
./rename.sh --force .

# Combine options
./rename.sh --anime --deep-clean --format "Show - SxxExx" --verbose --dry-run "/path/to/anime"
```

---

## Command Line Options

| Option            | Description                                 |
| ----------------- | ------------------------------------------- |
| `--dry-run`       | Preview changes without making them         |
| `--verbose`       | Show detailed processing information        |
| `--force`         | Overwrite existing files (use with caution) |
| `--deep-clean`    | Clean internal MKV/MP4 metadata and rename companion files |
| `--anime`         | Enable anime/fansub mode (prioritizes anime patterns) |
| `--series "Name"` | Manually specify series name                |
| `--format FORMAT` | Choose output format (see formats below)   |
| `--help`, `-h`    | Show help message                           |

---

## Output Formats

### `Show (Year) - SxxExx - Title` (Recommended for TV shows with episode titles)
```
Breaking Bad (2008) - S01E01 - Pilot.mkv
Breaking Bad (2008) - S01E02 - Cat's in the Bag.mkv
```

### `Show (Year) - SxxExx` (Clean format with year)
```
3 Body Problem (2024) - S01E01.mkv
Breaking Bad (2008) - S01E02.mkv
```

### `Show - SxxExx - Title` (Good for shows with episode titles)
```
Breaking Bad - S01E01 - Pilot.mkv
Breaking Bad - S01E02 - Cat's in the Bag.mkv
```

### `Show - SxxExx` (Recommended for anime)
```
3 Body Problem - S01E01.mkv
Breaking Bad - S01E02.mkv
Cyberpunk Edgerunners - S01E01.mkv
```

### `SxxExx - Title` (Episode-focused with titles)
```
S01E01 - Pilot.mkv
S01E02 - Cat's in the Bag.mkv
```

### `SxxExx` (Minimal format)
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

### With Episode Titles (using `--format "Show (Year) - SxxExx - Title"`)
```
Breaking Bad (2008)/
├── Season 1/
│   ├── Breaking Bad (2008) - S01E01 - Pilot.mkv
│   └── Breaking Bad (2008) - S01E02 - Cat's in the Bag.mkv
└── Season 2/
    └── Breaking Bad (2008) - S02E01 - Seven Thirty-Seven.mkv
```

---

## Deep Clean Feature (`--deep-clean`)

The `--deep-clean` option provides comprehensive metadata cleanup for video files:

### Supported Formats:
- **MKV files**: Always cleaned (container titles, track names, metadata)
- **MP4/M4V files**: Only cleaned if they contain problematic metadata
- **Other formats**: Companion file renaming only

### What it cleans:
- **Container titles**: Sets to match your clean filename
- **Track names**: Removes technical metadata from video/audio/subtitle tracks
- **Companion files**: Automatically renames .srt, .nfo, .jpg files to match

### MP4 Intelligence:
The script automatically detects if MP4 files need cleaning by checking for:
- Technical indicators (720p, x264, webrip, etc.)
- Release group artifacts
- Files with clean/empty titles are skipped automatically

### Before deep clean (internal MKV metadata):
```
Container title: "GalaxyRG265 - Perfect.Blue.1997.JAPANESE.REMASTERED.1080p.BluRay.DDP5.1.x265.10bit-GalaxyRG265"
Video track: "GalaxyRG265 - Perfect.Blue.1997.JAPANESE.REMASTERED.1080p.BluRay.DDP5.1.x265.10bit-GalaxyRG265"
Audio track: "Stereo"
```

### After deep clean:
```
Container title: "Breaking Bad (2008) - S01E01 - Pilot"
Video track: (no title)
Audio track: (no title)
```

---

## Auto-Detection Features

The script automatically:

- **Detects series name** from folder structure (e.g., "3 Body Problem (2024)" → "3 Body Problem")
- **Preserves years** when using appropriate formats
- **Recognizes episode patterns**: `S01E01`, `S01 E01`, `S1E1`, `1x01`, `01x01`, `- 01 [Quality]`
- **Handles anime/fansub formats**: Detects `[Group] Show - Episode [Metadata]` patterns
- **Intelligently extracts episode titles** using boundary detection to separate titles from technical metadata
- **Preserves meaningful parenthetical content** like "(Part 1)", "(Extended Cut)", "(Director's Cut)" while removing technical metadata
- **Cleans filenames** by removing:
  - Quality indicators (720p, 1080p, 4K, etc.)
  - Codec info (x264, x265, HEVC, H264)
  - Source tags (WEB, WEB-DL, BluRay, BDRip, HDTV)
  - Audio info (AAC, AC3, DTS)
  - Platform tags (AMZN, NFLX, HULU, etc.)
  - Release group names and fansub group tags (both uppercase and lowercase)
  - Hash codes in anime releases (like `[ABC123]`)
  - Technical abbreviations and tags

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

- **Series Name Validation**: Prevents series name variants from being used as episode titles
- **Smart Deduplication**: Avoids duplicate titles within the same season
- **Boundary Detection**: Identifies where technical metadata begins (e.g., at quality indicators like "720p")
- **MediaInfo Fallback**: Attempts to extract real episode titles from container metadata when filename parsing fails
- **Intelligent Rejection**: Drops titles that match series names or contain only technical metadata
- **Enhanced Cleaning**: Removes series names, years, and technical tags while preserving actual episode titles
- **Edge Case Handling**: Properly handles parentheses, brackets, and complex filename structures

---

## Safety Features

- **Idempotent**: Safe to run multiple times
- **Validation**: Checks file existence and prevents overwrites
- **Dry-run**: Preview all changes before applying
- **Backup-friendly**: Original files only moved, not copied
- **Error handling**: Graceful failure with detailed error messages
- **Permission handling**: Automatically fixes read-only files when possible
- **Subtitle preservation**: Maintains language codes in subtitle files
- **No double-processing**: Prevents companion files from being renamed twice

---

## Troubleshooting

### No files found
- Check file extensions are supported (mkv, mp4, avi, etc.)
- Verify the path is correct
- Use `--verbose` to see what the script is detecting

### Episode patterns not detected
- **For spaced formats**: The script now supports `S01 E01` format automatically
- **For anime**: Try `--anime` flag for fansub releases
- Check that files follow supported patterns (`S01E01`, `S01 E01`, `- 01 [Quality]`)
- Use `--verbose` to see which patterns are being tested
- For unusual formats, consider `--series` override

### Series name not detected correctly
- **Ensure proper folder structure**: Each show should have its own folder
- Use `--series "Exact Series Name"` to override auto-detection
- Check that the folder name contains the series name (e.g., "Breaking Bad (2008)")
- Use `--verbose` to see detection process
- Avoid mixing multiple shows in one folder

### Episode titles not clean
- The script uses improved boundary detection for cleaner titles
- Use `--format "Show - SxxExx"` to avoid including titles if they're still problematic
- Consider manually specifying `--series` for better cleaning
- For anime, try `--anime` flag which defaults to no episode titles

### Permission errors
- The script automatically attempts to fix read-only files
- Ensure you have write permissions to the directory
- On WSL, check Windows file permissions
- Try running with appropriate user privileges

### Metadata cleanup not working
- Ensure MKVToolNix is installed for `--deep-clean` functionality
- Check that files are actually MKV format (metadata cleanup only works on MKV/MP4)
- Use `--verbose` to see detailed processing information
- On Windows/WSL: install MKVToolNix **inside WSL** or add the Windows install path to WSL's `PATH`

### Subtitles being processed twice
- This has been fixed - companion subtitles are no longer double-processed during `--deep-clean`

---

## Examples by Show Type

### Standard TV Show
```bash
./rename.sh --format "Show (Year) - SxxExx" --dry-run "/path/to/office"
```

### Standard TV Show with Episode Titles and Deep Clean
```bash
./rename.sh --deep-clean --format "Show (Year) - SxxExx - Title" --dry-run "/path/to/office"
```

### Anime (with anime mode and deep clean)
```bash
./rename.sh --anime --deep-clean --dry-run "/path/to/anime/show"
./rename.sh --anime --deep-clean --format "Show - SxxExx" --series "Attack on Titan" --dry-run "/path/to/aot"
```

### Shows with episode titles
```bash
./rename.sh --format "Show - SxxExx - Title" --dry-run "/path/to/show-with-good-titles"
```

### Clean, minimal naming with metadata cleanup
```bash
./rename.sh --deep-clean --format "SxxExx" --dry-run "/path/to/shows"
```

---

## Tips

1. **Always use `--dry-run` first** to preview changes
2. **Organize shows properly**: Each show should have its own folder before running the script
3. **Use `--anime` for fansub releases** and anime with non-standard naming
4. **Use `--deep-clean` for MKV/MP4 files** to clean internal metadata and companion files
5. **Use `--verbose`** when troubleshooting or understanding the parsing process
6. **Start with `"Show (Year) - SxxExx"` format** for TV shows - it's very compatible
7. **Use `"Show - SxxExx"` format for anime** - cleaner and more appropriate
8. **Try `"Show (Year) - SxxExx - Title"` for shows with good episode titles**
9. **Specify `--series`** if auto-detection isn't working well
10. **Process shows individually** rather than running on a mixed folder
11. **Make backups** of important collections before running
12. **Test on a small subset** before processing large collections
13. **The script preserves meaningful parenthetical content** like "(Part 1)" while removing technical metadata
14. **Permission issues are handled automatically** when possible
15. **Spaced episode formats work automatically** - no special flags needed for `S01 E01` vs `S01E01`

---

## Requirements

- Bash 4.0+ (most modern systems)
- Standard Unix tools (`find`, `sed`, etc.)
- Write permissions to target directories

### Optional Dependencies (for `--deep-clean`)
- **MKVToolNix** (`mkvpropedit`, `mkvmerge`) - Required for MKV metadata cleanup
- **FFmpeg** - Required for MP4 metadata cleanup
- **MediaInfo** - Required for MP4 metadata detection and episode title extraction
  - Ubuntu/Debian: `sudo apt install mkvtoolnix ffmpeg mediainfo`
  - macOS: `brew install mkvtoolnix ffmpeg mediainfo`
  - **Note**: Script works without these tools but skips metadata cleanup

---

## Contributors

Thanks to the following people who have contributed to this project:

- **[@matthiasbeyer](https://github.com/matthiasbeyer)** - Added shellcheck CI workflow for automated code quality checks

---

## License

This script is provided as-is for personal use. Feel free to modify and distribute.