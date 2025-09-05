# Next Steps

## Recently Completed ✅

### Fixed: Overmatching of release tags in episode titles
**Problem:** Files like "Doctor.Who.2005.S05E04.Time.Of.The.Angels.HDTV.XviD-FoV.avi" were producing incorrect titles like `The Angels HDTV FoV`

**Solution implemented:** Enhanced boundary detection that identifies where technical metadata starts (quality indicators, codecs, etc.) and cuts the title there, preventing release tags from contaminating episode titles.

---

## Future Enhancements

### 1. Filename Format Options
Add configurable output formats to support different media server preferences:

**Proposed formats:**
- Current: `Show Name - SxxExx - Title.ext` 
- With year: `Show Name (Year) - SxxExx - Title.ext`
- Minimal: `Show Name - SxxExx.ext`

**Implementation:**
- Add `--format` flag with options like `standard`, `with-year`, `minimal`
- Configuration file support for default format preference
- Per-show format overrides for mixed libraries

**Use cases:**
- Better compatibility across different media managers (Plex, Emby, Kodi)
- Clearer identification when files are moved outside folder structure
- Consistency preferences across entire media library
- Legacy system compatibility requirements

### 2. External Episode Database Integration
Cross-reference episode titles with external APIs for validation and correction:

- **TMDB (The Movie Database)** - Free API with good TV coverage
- **IMDB** - Comprehensive but more complex to access
- **TVMaze** - Simple API, good for episode listings

**Use cases:**
- Validate extracted titles against known episode names
- Fill in missing titles when boundary detection fails
- Correct minor extraction errors (punctuation, capitalization)
- Handle special episodes that don't follow standard patterns

**Implementation ideas:**
- Add `--lookup` flag to enable API checking
- Cache results locally to avoid repeated API calls
- Fallback gracefully when API is unavailable

### 3. Interactive/Manual Renaming Mode
Handle edge cases where auto-detection fails:

**Problem files:**
- Specials that don't match S00Exx patterns
- Episodes with unusual naming conventions
- Files where title extraction completely fails

**Proposed solution:**
- Add `--interactive` flag for manual review mode
- Present suggested renames for user approval/editing
- Provide smart suggestions:
  - `S00E01`, `S00E02` for detected specials
  - Season/episode detection with manual title input
  - Skip option for files that can't be processed

**Interface mockup:**
```
Found: "Doctor.Who.Christmas.Special.2023.mkv"
Suggested: "Doctor Who (2005) - S00E01.mkv"
Options: [A]ccept, [E]dit, [S]kip, [Q]uit
```

### 4. Additional Pattern Recognition
- Better handling of multi-part episodes (Part 1, Part 2)
- Anime episode numbering patterns
- Movie/special naming conventions
- Date-based episode naming (news shows, daily content)

### 5. Quality of Life Improvements
- Configuration file support (`.renamerrc`)
- Batch processing with progress indicators
- Undo functionality (save rename log for reversal)
- Integration with media server APIs for immediate library refresh

---

## Low Priority / Nice to Have

- Web interface for remote management
- Docker container for easy deployment
- Plugin system for custom naming schemes
- Integration with download managers (Sonarr, etc.)

---

## Implementation Notes

When adding external API features:
- Keep it optional (don't break existing functionality)
- Handle rate limiting gracefully
- Provide offline fallback mode
- Consider privacy implications of API calls

When implementing format options:
- Maintain backward compatibility with existing scripts
- Consider file path length limitations on different filesystems
- Test with various special characters in show names and years