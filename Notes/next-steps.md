# Next Steps

## Recently Completed ✅

### Enhanced Boundary & Title Extraction
**Problems solved:** Files like "Doctor.Who.2005.S05E04.Time.Of.The.Angels.HDTV.XviD-FoV.avi" were producing incorrect titles like `The Angels HDTV FoV`

**Solutions implemented:**
- **Enhanced boundary detection** that identifies where technical metadata starts (quality indicators, codecs, etc.) and cuts the title there
- **Fixed:** Technical parentheses now dropped while preserving meaningful ones like `(Part 1)`, `(Director's Cut)`
- **Fixed:** Release group removal works case-insensitively (uppercase/lowercase groups)
- **Fixed:** Deduplication of double separators (`--`) after series/year cleanup
- **Improved:** Cleaner handling of orphaned years and leading dashes
- **Added:** Subtitle support with language code preservation (`.en.srt`, `.eng.srt`)
- **Added:** Multiple output formats with `--format` flag supporting 6 different naming schemes
- **Added:** Anime mode (`--anime`) with default `Show - SxxExx` format and fansub pattern support

---

## Future Enhancements

### 1. External Episode Database Integration
Cross-reference episode titles with external APIs for validation and correction:

**Proposed APIs:**
- **TMDB (The Movie Database)** - Free API with good TV coverage
- **IMDB** - Comprehensive but more complex to access
- **TVMaze** - Simple API, good for episode listings

**Use cases:**
- Validate extracted titles against known episode names
- Fill in missing titles when boundary detection fails
- Correct minor extraction errors (punctuation, capitalization)
- Handle special episodes that don't follow standard patterns

**Implementation approach:**
- Add `--lookup` flag to enable API checking
- Cache results locally to avoid repeated API calls
- Fallback gracefully when API is unavailable or rate-limited
- Keep it completely optional to preserve existing workflow

### 2. Interactive/Manual Renaming Mode
Handle edge cases where auto-detection fails:

**Problem scenarios:**
- Specials that don't match S00Exx patterns
- Episodes with unusual naming conventions
- Files where title extraction completely fails
- Mixed episode formats in the same series

**Proposed solution:**
- Add `--interactive` flag for manual review mode
- Present suggested renames for user approval/editing
- Provide smart suggestions based on detected patterns

**Interface concept:**
```
Found: "Doctor.Who.Christmas.Special.2023.mkv"
Detected: No standard episode pattern
Suggested: "Doctor Who (2005) - S00E01.mkv"
Options: [A]ccept, [E]dit title, [S]kip, [Q]uit
```

### 3. Additional Pattern Recognition
Expand pattern support for edge cases:

- **Multi-part episodes:** Better handling beyond current `(Part 1)` preservation
- **Broader anime numbering:** Support for OVAs, movies, and non-standard episode counts
- **Movie/special conventions:** Christmas specials, anniversary episodes, etc.
- **Date-based formats:** News shows, daily content with YYYY-MM-DD patterns
- **Anthology series:** Different naming requirements for shows like Black Mirror

### 4. Quality of Life Improvements
Enhance user experience and workflow:

**Configuration system:**
- Support for `.renamerrc` config file for default preferences
- Per-directory configuration overrides
- Project-specific naming schemes

**Safety and convenience:**
- Undo functionality via rename operation logs
- Batch processing with progress indicators
- Resume capability for interrupted large operations
- Integration hooks for media server APIs (Jellyfin, Plex) for automatic library refresh

**Performance:**
- Parallel processing for large libraries
- Memory-efficient processing of huge directory structures
- Smarter caching of series detection results

---

## Low Priority / Nice to Have

- **Web interface** for remote library management
- **Docker container** for easy deployment and isolation
- **Plugin system** for custom naming schemes and corporate environments
- **Integration with download managers** (Sonarr, Radarr) for automated post-processing
- **Machine learning** title extraction for particularly messy filename patterns

---

## Implementation Notes

### API Integration Guidelines
- Keep all external features completely optional
- Handle rate limiting gracefully with exponential backoff
- Provide robust offline fallback mode
- Consider privacy implications and allow opt-out
- Cache API responses locally to minimize requests

### Compatibility Considerations
- Maintain strict backward compatibility with existing command-line interface
- Test with various filesystem limitations (path length, special characters)
- Ensure cross-platform compatibility (Linux, macOS, Windows/WSL)
- Preserve dry-run safety as the default behavior

### Code Quality
- Maintain current modular function structure
- Add comprehensive test coverage for new features
- Document all new command-line options thoroughly
- Keep dependencies minimal (pure Bash + standard Unix tools)