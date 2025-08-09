# Next Steps

## Goal: Fix overmatching of release tags in episode titles

Problem example:
- "Doctor.Who.2005.S05E04.Time.Of.The.Angels.HDTV.XviD-FoV.avi"
- Current output: `The Angels HDTV FoV` → Incorrect

### Solution Ideas:
- Strip common release keywords from end of title (HDTV, XviD, etc.)
- Require matched title to come **before** first all-caps tag
- Use a known episode list from IMDB or TVMaze to validate title boundaries
- Add a `--strict-title` flag to exclude anything matching `[A-Z]{2,}` or bracketed tags

This is a soft failure now — rename still works, just not cleanly.
