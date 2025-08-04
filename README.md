# Universal Media Renamer for Jellyfin/Plex

A robust Bash script that automatically renames TV show files to be compatible with Jellyfin, Plex, and other media servers.

> ⚠️ **Disclaimer**  
> This script is in active development and may have bugs.  
> Always use `--dry-run` first and test on backups or small batches.  
> Pull requests, feedback, and issues are welcome!

## Features

- **Smart Pattern Detection**: Handles multiple episode naming patterns (`S01E01`, `1x01`, etc.)
- **Auto Series Detection**: Automatically detects series name from folder structure
- **Intelligent Cleaning**: Strips codec info, quality tags, and release group names
- **Multiple Formats**: Supports various output formats including year preservation
- **Safe Operation**: Dry-run mode and comprehensive validation
- **Cross-Platform**: Works on Linux, macOS, and Windows (WSL)

## Supported File Types

**Video**: mkv, mp4, avi, m4v, mov, wmv, flv, webm, ts, m2ts

## Quick Start

```bash
# Make executable
chmod +x rename.sh

# Preview changes (recommended first run)
./rename.sh --dry-run /path/to/your/tv/shows

# Apply changes
./rename.sh /path/to/your/tv/shows
```

## Usage Examples

### Basic Usage
```bash
# Process current directory
./rename.sh --dry-run .

# Process specific path
./rename.sh --dry-run "/mnt/media/TV Shows"
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
./rename.sh --format "Show (Year) - SxxExx" --verbose --dry-run "/path/to/shows"
```

## Command Line Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Preview changes without making them |
| `--verbose` | Show detailed processing information |
| `--force` | Overwrite existing files (use with caution) |
| `--series "Name"` | Manually specify series name (auto-detected if not provided) |
| `--format FORMAT` | Choose output format (see formats below) |
| `--help`, `-h` | Show help message |

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

## What It Does

### Before
```
3 Body Problem (2024)/
├── 3.Body.Problem.S01E01.1080p.WEB.H264-StereotypedGazelleOfWondrousPassion.mkv
├── 3.Body.Problem.S01E02.1080p.WEB.H264-StereotypedGazelleOfWondrousPassion.mkv
└── Breaking.Bad.1x03.720p.WEB-DL.x264-GROUP.mkv
```

### After (using `--format "Show (Year) - SxxExx"`)
```
3 Body Problem (2024)/
├── 3 Body Problem (2024) - S01E01.mkv
├── 3 Body Problem (2024) - S01E02.mkv
└── Breaking Bad (2008) - S01E03.mkv
```

## Auto-Detection Features

The script automatically:

- **Detects series name** from folder structure (e.g., "3 Body Problem (2024)" → "3 Body Problem")
- **Preserves years** when using appropriate formats
- **Recognizes episode patterns**: `S01E01`, `S1E1`, `1x01`, `01x01`
- **Cleans filenames** by removing:
  - Quality indicators (720p, 1080p, 4K, etc.)
  - Codec info (x264, x265, HEVC, H264)
  - Source tags (WEB, WEB-DL, BluRay, BDRip)
  - Audio info (AAC, AC3, DTS)
  - Release group names (like "StereotypedGazelleOfWondrousPassion")

## Safety Features

- **Idempotent**: Safe to run multiple times
- **Validation**: Checks file existence and prevents overwrites
- **Dry-run**: Preview all changes before applying
- **Backup-friendly**: Original files only moved, not copied
- **Error handling**: Graceful failure with detailed error messages

## Troubleshooting

### No files found
- Check file extensions are supported (mkv, mp4, avi, etc.)
- Verify the path is correct
- Use `--verbose` to see what the script is detecting

### Series name not detected correctly
- Use `--series "Exact Series Name"` to override auto-detection
- Check folder name contains the series name
- Use `--verbose` to see detection process

### Episode titles not clean
- Release group names may be difficult to automatically remove
- Use `--format "Show - SxxExx"` to avoid including problematic titles
- Consider manually specifying `--series` for better cleaning

### Permission errors
- Ensure you have write permissions to the directory
- On WSL, check Windows file permissions
- Try running with appropriate user privileges

## Examples by Show Type

### Standard TV Show
```bash
./rename.sh --format "Show (Year) - SxxExx" --dry-run "/path/to/office"
```

### Anime
```bash
./rename.sh --format "Show - SxxExx" --series "Attack on Titan" --dry-run "/path/to/aot"
```

### Shows with episode titles
```bash
./rename.sh --format "Show - SxxExx - Title" --dry-run "/path/to/show-with-good-titles"
```

### Clean, minimal naming
```bash
./rename.sh --format "SxxExx" --dry-run "/path/to/shows"
```

## Tips

1. **Always use `--dry-run` first** to preview changes
2. **Use `--verbose`** when troubleshooting
3. **Start with `"Show (Year) - SxxExx"` format** - it's the most compatible
4. **Specify `--series`** if auto-detection isn't working well
5. **Make backups** of important collections before running
6. **Test on a small subset** before processing large collections

## Requirements

- Bash 4.0+ (most modern systems)
- Standard Unix tools (`find`, `sed`, etc.)
- Write permissions to target directories

## License

This script is provided as-is for personal use. Feel free to modify and distribute.