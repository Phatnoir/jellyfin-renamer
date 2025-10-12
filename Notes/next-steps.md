# Next Steps

## Recently Completed ✅

### Enhanced Boundary & Title Extraction
- Enhanced boundary detection for cleaner title extraction
- Technical vs. meaningful parentheses handling (preserve "Part 1", drop "720p")
- Case-insensitive release group removal
- Subtitle support with language code preservation
- Multiple output formats via `--format` flag
- Anime mode with fansub pattern support

### MP4 Metadata Deep-Clean
- Deep-clean mode removes technical metadata from MP4/MKV containers
- Companion file renaming for subtitles and sidecars
- Automated Python testing infrastructure
- Enhanced verbose logging for debugging

**Current status:** Bash version feature-complete and stable at ~1,300 lines.

---

## Primary Focus: Python Migration 🎯

### Why Migrate
- Script has outgrown bash (1,300 lines, complex interdependencies)
- Difficult to test and maintain
- Security concerns (command injection, unsafe temp files)
- Every fix adds complexity instead of reducing it

### What We Gain
- 40-50% smaller codebase (~800 lines vs 1,300)
- Automated testing with pytest
- Better security by default
- Clearer structure and easier debugging
- Same user experience (identical CLI)

### Migration Approach
1. Extract bash behavior into Python unit tests (establish ground truth)
2. Build Python modules one at a time, test-driven
3. Validate Python output matches bash output
4. Keep ALL bespoke rules (anime patterns, specials handling, title extraction logic)

**Zero functionality loss** - we're translating, not redesigning.

---

## Future Enhancements
*(Much easier once migrated to Python)*

### API Integration
- External episode database lookup (TMDB, TVMaze, IMDB)
- Validate and fill in missing episode titles
- Handle special episodes outside standard patterns

### Interactive Mode
- Manual review for edge cases
- User approval/editing of suggested renames
- Smart suggestions based on detected patterns

### Configuration System
- `.renamerrc` for default preferences
- Per-directory overrides
- Project-specific naming schemes

### Quality of Life
- Undo functionality via operation logs
- Progress bars for large batches
- Parallel processing
- Resume capability for interrupted operations

---

## Key Principle

**The goal:** Transform from "I hope this works" to "I know this works because tests prove it."

Migration isn't about adding features - it's about building a foundation where features can be added safely.