# Universal Media Renamer for Jellyfin/Plex

A robust Bash script that automatically renames TV show files and folders to be compatible with Jellyfin, Plex, and other media servers.

> ⚠️ **Disclaimer**  
> This script is in active development and may have bugs.  
> Always use `--dry-run` first and test on backups or small batches.  
> Pull requests, feedback, and issues are welcome!

## Features

- **Smart Pattern Detection**: Handles multiple episode naming patterns (`S01E01`, `1x01`, `Episode 1`, etc.)
- **Title Extraction**: Automatically extracts and cleans episode titles
- **Junk Removal**: Strips codec info, group tags, and other metadata
- **Multiple Formats**: Supports various output formats to match your preferences
- **Safe Operation**: Dry-run mode and comprehensive validation
- **Cross-Platform**: Works on Linux, macOS, and Windows (WSL)

## Supported File Types

**Video**: mkv, mp4, avi, m4v, mov, wmv, flv  
**Subtitles**: srt, ass, ssa, vtt, sub

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

### With Series Name
```bash
# Strip series name from filenames
./rename.sh --series "Breaking Bad" --dry-run "/path/to/breaking-bad"

# For My Little Pony example
./rename.sh --series "My Little Pony" --dry-run "/path/to/mlp"
```

### Different Output Formats
```bash
# Minimal format (S01E01.mkv)
./rename.sh --format "SxxExx" --dry-run .

# Verbose format (Season 1 Episode 1 - Title.mkv)
./rename.sh --format "Season X Episode Y - Title" --dry-run .

# Default format (S01E01 - Title.mkv)
./rename.sh --format "SxxExx - Title" --dry-run .
```

### Advanced Options
```bash
# Verbose output for debugging
./rename.sh --verbose --dry-run .

# Force overwrite existing files (use with caution)
./rename.sh --force .

# Combine options
./rename.sh --series "Game of Thrones" --verbose --dry-run "/path/to/got"
```

## Command Line Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Preview changes without making them |
| `--verbose` | Show detailed processing information |
| `--force` | Overwrite existing files (use with caution) |
| `--series "Name"` | Specify series name to strip from filenames |
| `--format FORMAT` | Choose output format (see formats below) |
| `--help`, `-h` | Show help message |

## Output Formats

### `SxxExx - Title` (Default)
```
S01E01 - Pilot.mkv
S01E02 - The Morning After.mkv
```

### `SxxExx`
```
S01E01.mkv
S01E02.mkv
```

### `Season X Episode Y - Title`
```
Season 1 Episode 1 - Pilot.mkv
Season 1 Episode 2 - The Morning After.mkv
```

## What It Does

### Before
```
Breaking Bad S01E01 - Pilot (1080p x265 HEVC AAC) [Group].mkv
Breaking.Bad.1x02.Cat's.in.the.Bag.720p.WEB-DL.x264.mkv
Season 1/
└── Breaking Bad - Episode 3 - And the Bag's in the River (BDRip).mkv
```

### After
```
Season 1/
├── S01E01 - Pilot.mkv
├── S01E02 - Cat's in the Bag.mkv
└── S01E03 - And the Bag's in the River.mkv
```

## Input Pattern Recognition

The script automatically detects these patterns:

- **Season/Episode**: `S01E01`, `S1E1`, `s01e01`
- **Alternative**: `1x01`, `01x01`
- **Verbose**: `Season 1 Episode 1`, `Season 01 Episode 01`
- **Simple**: `Episode 1`, `Ep 1` (with season inference)

## Safety Features

- **Idempotent**: Safe to run multiple times
- **Validation**: Checks file existence and prevents overwrites
- **Dry-run**: Preview all changes before applying
- **Backup-friendly**: Original files only moved, not copied
- **Error handling**: Graceful failure with detailed error messages

## Troubleshooting

### No files found
- Check file extensions are supported
- Verify the path is correct
- Use `--verbose` to see what the script is detecting

### Season folders not renamed
- Only file renaming is supported at the moment
- Ensure folder names contain "Season" or "S01" patterns
- Check that you have write permissions
- Use `--verbose` to see folder detection

### Episode titles not extracted
- Some files may not have recognizable title patterns
- The script will fall back to "Episode X" format
- Use `--series "Show Name"` to help with title extraction

### Permission errors
- Ensure you have write permissions to the directory
- On WSL, check Windows file permissions
- Try running with appropriate user privileges

## Examples by Show Type

### Standard TV Show
```bash
./universal_rename.sh --series "The Office" --dry-run "/path/to/office"
```

### Anime
```bash
./universal_rename.sh --series "Attack on Titan" --verbose --dry-run "/path/to/aot"
```

### Complex naming
```bash
./universal_rename.sh --series "My Little Pony Friendship Is Magic" --dry-run "/path/to/mlp"
```

## Tips

1. **Always use `--dry-run` first** to preview changes
2. **Use `--verbose`** when troubleshooting
3. **Specify `--series`** for better title extraction
4. **Make backups** of important collections before running
5. **Test on a small subset** before processing large collections

## Requirements

- Bash 4.0+ (most modern systems)
- Standard Unix tools (`find`, `sed`, etc.)
- Write permissions to target directories

## License

This script is provided as-is for personal use. Feel free to modify and distribute.