# Universal Media Renamer for Jellyfin/Plex

A smart, cross-platform Python tool that renames TV show files so they work perfectly with Jellyfin, Plex, and other media servers without breaking your existing folder structure.

> ⚠️ **Disclaimer**
> This tool is under active development. Always use `--dry-run` first and test on backups or small batches. Pull requests, feedback, and issues are welcome!

---

## The Problem

You have 100 TV show files with inconsistent naming like:
- `Breaking.Bad.S01E01.Pilot.720p.WEB-DL.x264-GROUP.mkv`
- `Doctor.Who.2005.S05E04.Time.Of.The.Angels.HDTV.XviD-FoV.avi`
- `[Erai-raws] Cyberpunk - Edgerunners - 01 [1080p][Multiple Subtitle].mkv`

Jellyfin and Plex need them consistently named:
- `Breaking Bad (2008) - S01E01 - Pilot.mkv`
- `Doctor Who (2005) - S05E04 - Time of the Angels.avi`
- `Cyberpunk Edgerunners - S01E01.mkv`

This tool automates that transformation, handling codec tags, quality indicators, release groups, and anime/fansub formats automatically. It works safely with `--dry-run` so you preview changes before applying them.

---

## Quick Start (TL;DR)

```bash
# Install from source
pip install .

# Or install in development mode
pip install -e .

# ALWAYS preview first (safe, shows what would change)
rename --dry-run "/path/to/TV Shows/Breaking Bad (2008)"

# Once you're happy with the preview:
rename "/path/to/TV Shows/Breaking Bad (2008)"

# For anime/fansub releases:
rename --anime --dry-run "/path/to/Anime/Cyberpunk Edgerunners (2022)"

# With metadata cleanup (removes internal codec info from files):
rename --deep-clean --dry-run "/path/to/TV Shows/Breaking Bad (2008)"
```

### Sample dry-run output
```
[DRY] Breaking.Bad.S01E01.Pilot.720p.WEB-DL.x264-GROUP.mkv
    → Breaking Bad (2008) - S01E01 - Pilot.mkv
```

**Windows/WSL note**: For `--deep-clean`, install MKVToolNix, FFmpeg, and MediaInfo *inside WSL*, not on Windows. The tool needs them available in the WSL environment.

---

## How It Works

The tool automatically:

- **Detects series name** from your folder structure (e.g., "Breaking Bad (2008)" → "Breaking Bad")
- **Recognizes episode patterns**:
  - Standard TV: `S01E01`, `S01 E01`, `1x01`, `01x01`
  - Anime/Fansub: `[Group] Show - 01 [Quality]`, `Show - 01 [Metadata]`
- **Extracts episode titles** using boundary detection to separate real titles from technical metadata
- **Cleans filenames** by removing:
  - Quality indicators (720p, 1080p, 4K, etc.)
  - Codec info (x264, x265, HEVC)
  - Source tags (WEB, BluRay, HDTV, etc.)
  - Platform tags (AMZN, NFLX, HULU)
  - Release group names and hash codes
- **Preserves meaningful content** like "(Part 1)" or "(Director's Cut)" while removing technical junk
- **Handles subtitles** by automatically renaming .srt files to match their video, preserving language codes
- **Optionally cleans internal metadata** with `--deep-clean` (removes codec info embedded inside MKV/MP4 files)

---

## Folder Structure Requirements

**IMPORTANT**: This tool works best with properly organized TV show folders. Each show should have its own folder:

### Recommended Structure
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

### What NOT to do
```
Mixed Folder/
├── Breaking.Bad.S01E01.mkv          ← Will become "Mixed Folder - S01E01.mkv"
├── Doctor.Who.S05E04.avi            ← Will become "Mixed Folder - S05E04.avi"
└── 3.Body.Problem.S01E01.mkv        ← Will become "Mixed Folder - S01E01.mkv"
```
The tool uses your folder name as the series name. Organize each show into its own folder before running.

---

## Command-Line Flags

| Flag | Purpose |
|------|---------|
| `--dry-run` | Preview changes without making them (do this first!) |
| `--series "Name"` | Override auto-detected series name |
| `--format FORMAT` | Choose output filename format (see formats below) |
| `--anime` | Enable anime/fansub mode (prioritizes `- 01 [Quality]` patterns) |
| `--deep-clean` | Clean internal MKV/MP4 metadata and rename companion files |
| `--verbose` | Show detailed debugging information |
| `--force` | Overwrite existing files if destination already exists |
| `--version` | Show version number |
| `--help` | Show help message |

### Combining Flags
```bash
rename --anime --deep-clean --format "Show - SxxExx" --verbose --dry-run "/path/to/anime"
```

---

## Output Formats

Choose how your final filenames look:

| Format | Example |
|--------|---------|
| `Show (Year) - SxxExx` | `Breaking Bad (2008) - S01E01.mkv` |
| `Show (Year) - SxxExx - Title` | `Breaking Bad (2008) - S01E01 - Pilot.mkv` |
| `Show - SxxExx` | `Cyberpunk Edgerunners - S01E01.mkv` |
| `Show - SxxExx - Title` | `Breaking Bad - S01E01 - Pilot.mkv` |
| `SxxExx - Title` | `S01E01 - Pilot.mkv` |
| `SxxExx` | `S01E01.mkv` |

**Recommended**: Use `Show (Year) - SxxExx` for TV shows, `Show - SxxExx` for anime.

---

## Deep Clean Feature (`--deep-clean`)

This option cleans internal metadata from video files and renames companion files (subtitles, artwork, NFO).

### What It Does
- **MKV files**: Clears container titles and removes technical metadata tags from video/audio/subtitle tracks. The streams themselves are untouched—only their internal title labels are removed.
- **MP4 files**: Sets clean container title (only if file contains problematic metadata)
- **Companion files**: Renames external .srt, .nfo, .jpg files to match their video, preserving language codes (e.g., `show.en.srt` stays `show.en.srt`)

### About Internal Track Titles
If your MKV has 5 subtitle streams with internal titles (common in multi-language releases), `--deep-clean` will clear those title labels. The subtitle streams themselves remain intact—this is normal and expected for multi-language files. External subtitle files (.srt, .ass) are handled separately and keep their language codes intact.

---

## Anime Mode (`--anime`)

Use this for fansub releases and anime with non-standard naming. The flag:

- **Prioritizes anime patterns** like `- 01 [Quality]` over standard TV patterns
- **Defaults season to 01** for single-season shows
- **Changes default format** to `Show - SxxExx` (cleaner for anime)
- **Handles fansub groups** like `[Erai-raws]`, `[SubsPlease]`, `[HorribleSubs]`
- **Removes hash codes** and complex metadata

### Example
```bash
# Before:
[Erai-raws] Cyberpunk - Edgerunners - 01 [1080p][Multiple Subtitle][ABC123].mkv

# After (with --anime):
Cyberpunk Edgerunners - S01E01.mkv
```

---

## Concrete Examples

### Standard TV Show
```bash
rename --dry-run "/path/to/TV Shows/Breaking Bad (2008)"
```
Converts all files to: `Breaking Bad (2008) - S01E01.mkv` format

### TV Show with Episode Titles and Metadata Cleanup
```bash
rename --deep-clean --format "Show (Year) - SxxExx - Title" --dry-run "/path/to/show"
```

### Anime/Fansub
```bash
rename --anime --deep-clean --dry-run "/path/to/Cyberpunk Edgerunners (2022)"
```
Converts anime files to: `Cyberpunk Edgerunners - S01E01.mkv`

### Override Series Name
```bash
rename --series "My Little Pony Friendship Is Magic" --dry-run "/path/to/mlp"
```

### Multiple Shows at Once
```bash
for show in "/path/to/TV Shows"/*; do
    rename --dry-run "$show"
done
```

---

## Safety Features

- **Idempotent**: Safe to run multiple times. Re-running on already-renamed files results in no changes.
- **Validation**: Checks file existence and prevents accidental overwrites
- **Dry-run**: Preview all changes before applying them
- **Collision handling**: If target file exists, the tool skips it unless `--force` is used
- **Permission handling**: Automatically fixes read-only files when possible
- **No double-processing**: Companion files renamed once, not twice
- **Graceful errors**: Detailed messages if something goes wrong

---

## Supported File Types

| Type | Extensions |
|------|-----------|
| **Video** | mkv, mp4, avi, m4v, mov, wmv, flv, webm, ts, m2ts |
| **Subtitles** | srt, sub, ass, ssa, vtt |

---

## Troubleshooting

### No files found
- Check extensions are supported (mkv, mp4, avi, etc.)
- Verify the path is correct
- Use `--verbose` to see detection details

### Episode patterns not detected
- For spaced formats like `S01 E01`: These work automatically
- For anime: Try the `--anime` flag
- For unusual formats: Use `--series "Name"` to override detection

### Series name not detected correctly
- **Ensure proper folder structure**: Each show in its own folder
- Use `--series "Exact Name"` to override
- Check folder name contains the series name (e.g., "Breaking Bad (2008)")

### Episode titles not clean
- Try `--format "Show - SxxExx"` to skip titles altogether
- Use `--series "Name"` for better cleaning
- For anime, use `--anime` which defaults to no titles

### Permission errors
- The tool automatically fixes read-only files
- Ensure you have write permissions to the directory
- On WSL, check Windows file permissions

### Metadata cleanup not working
- Install MKVToolNix inside WSL (not just on Windows)
- Check files are actually MKV format
- Use `--verbose` to see processing details

### Known Limitations
- Multi-episode files like `S01E01-E02` are treated as the first episode (`S01E01`)
- Specials may map as Season 00 depending on folder layout—ensure Specials folders are recognized or use `--series` override

---

## Essential Tips

1. **Always use `--dry-run` first** — it's your safety net
2. **Test on a small batch** before processing large collections
3. **Organize shows in separate folders** — one show per folder, one run per show
4. **Make backups** of important collections
5. **Use `--verbose` when debugging** — it shows exactly what the tool is detecting

---

## Installation

### From Source
```bash
git clone https://github.com/Phatnoir/jellyfin-renamer.git
cd jellyfin-renamer
pip install .
```

### Development Mode
```bash
pip install -e ".[dev]"
```

This installs the package in editable mode (code changes take effect immediately) with dev dependencies (pytest, etc.).

### Running Tests
```bash
pytest Tests/
```

### Releasing
1. Bump version in `pyproject.toml`
2. Commit: `git commit -am "Release X.Y.Z"`
3. Tag: `git tag -a vX.Y.Z -m "Release X.Y.Z"`
4. Push: `git push && git push --tags`

### Requirements
- Python 3.10 or higher
- No external dependencies for basic operation

### Optional Dependencies (for `--deep-clean`)
- **MKVToolNix** - Ubuntu/Debian: `sudo apt install mkvtoolnix`; macOS: `brew install mkvtoolnix`
- **FFmpeg** - Ubuntu/Debian: `sudo apt install ffmpeg`; macOS: `brew install ffmpeg`
- **MediaInfo** - Ubuntu/Debian: `sudo apt install mediainfo`; macOS: `brew install mediainfo`

The tool works without these but will skip metadata cleanup.

---

## Contributors

Thanks to the following people who have contributed to this project:

- **[@matthiasbeyer](https://github.com/matthiasbeyer)** - Added shellcheck CI workflow for the original Bash implementation

---

## License

MIT. See LICENSE for details. Provided **as-is**, without warranty.
