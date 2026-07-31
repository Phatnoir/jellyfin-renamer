"""
Episode pattern detection and parsing.

This module contains all the regex patterns for detecting episode information
from filenames. These patterns have been carefully tuned to handle:
- Standard TV: S01E01, S1E1, 1x01, 01x01
- Single-season: E01, E001, E010
- Anime/fansub: [Group] Show - 01 [Quality], Show - 01 [Metadata]
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path


@dataclass
class EpisodeInfo:
    """Parsed episode information."""
    season: int
    episode: int
    second_episode: int | None = None

    def format_code(self) -> str:
        """Format as S01E01 or S01E01-E02 style code."""
        def ep_str(n: int) -> str:
            return f"E{n:03d}" if n >= 100 else f"E{n:02d}"

        if self.second_episode is not None:
            return f"S{self.season:02d}{ep_str(self.episode)}-{ep_str(self.second_episode)}"
        return f"S{self.season:02d}{ep_str(self.episode)}"


# =============================================================================
# EPISODE PATTERN DEFINITIONS
# These are ordered by priority within their category
# =============================================================================

# Standard TV patterns
PATTERN_SXXEXX = re.compile(
    r'[Ss](\d{1,2})[\s_.-]*[Ee](\d{1,3})',
    re.IGNORECASE
)

PATTERN_NXNN = re.compile(
    r'(\d{1,2})x(\d{2,3})',
    re.IGNORECASE
)

# Single-season pattern (E01, E001, etc.)
PATTERN_EXX = re.compile(
    r'[Ee](\d{1,3})',
    re.IGNORECASE
)

# Anime/fansub pattern: " - 01 [" or " - 01 (" or " - 01."
# The key is: dash, space(s), digits, then bracket/paren/dot
PATTERN_ANIME = re.compile(
    r'-\s+(\d{1,3})\s*[\[\(.]'
)

# Leading-number-with-season pattern: "01. HORRIBLE_HISTORIES-S1.mp4"
# Structure:
#   ^(\d{1,3})      leading digits  -> EPISODE number
#   \.\s*           dot separator, optional whitespace
#   .*              any characters (the show name, etc.)
#   [-_][Ss](\d{1,2})   a dash/underscore then S## -> SEASON number
#   (?![Ee]?\d)     guard: the S## must NOT be part of an SxxExx code
#                   (e.g. "S02E05"); if it is, this pattern declines so the
#                   real SxxExx parser can handle it instead.
# Examples:
#   "01. HORRIBLE_HISTORIES-S1.mp4"  -> season=1, episode=1
#   "09. HORRIBLE_HISTORIES_S2.mp4"  -> season=2, episode=9
#   "03. Horrible Histories-S3.mp4"  -> season=3, episode=3
PATTERN_LEADING_NUMBER_WITH_SEASON = re.compile(
    r'^(\d{1,3})\.\s*.*[-_][Ss](\d{1,2})(?![Ee]?\d)'
)


def get_season_episode(filename: str, anime_mode: bool = False) -> EpisodeInfo | None:
    """
    Extract season and episode numbers from a filename.

    Args:
        filename: The filename to parse (with or without extension)
        anime_mode: If True, prioritize anime patterns over standard TV patterns

    Returns:
        EpisodeInfo if detected, None otherwise

    Pattern priority (anime_mode=True):
        1. Anime pattern (- 01 [)
        2. Leading-number-with-season (01. Show-S1)
        3. Standard SxxExx
        4. NxNN format
        5. E## format

    Pattern priority (anime_mode=False):
        1. Leading-number-with-season (01. Show-S1)
        2. Standard SxxExx
        3. NxNN format
        4. E## format
        5. Anime pattern (fallback)
    """
    season: int | None = None
    episode: int | None = None

    if anime_mode:
        # Try anime patterns first
        match = PATTERN_ANIME.search(filename)
        if match:
            season = 1  # Default season for anime
            episode = int(match.group(1))
            return EpisodeInfo(season=season, episode=episode)

    # Pattern 0 (high priority): "01. Show-S1.mp4" style names.
    # Checked BEFORE the standard SxxExx/NxNN/E## patterns because the leading
    # number is the authoritative episode number for these files, and the season
    # lives in a trailing "-S#"/"_S#" tag that the other patterns don't recognize.
    # The regex's own (?![Ee]?\d) guard makes it decline anything that is really
    # an SxxExx code, so genuine "01. Show-S02E05" names still fall through below.
    match = PATTERN_LEADING_NUMBER_WITH_SEASON.match(filename)
    if match:
        episode = int(match.group(1))
        season = int(match.group(2))
        return EpisodeInfo(season=season, episode=episode)

    # Standard patterns (always try these if anime didn't match)

    # Pattern 1: S01E01, S1E1, etc.
    match = PATTERN_SXXEXX.search(filename)
    if match:
        season = int(match.group(1))
        episode = int(match.group(2))
        return EpisodeInfo(season=season, episode=episode)

    # Pattern 2: 1x01, 01x01, etc.
    match = PATTERN_NXNN.search(filename)
    if match:
        season = int(match.group(1))
        episode = int(match.group(2))
        return EpisodeInfo(season=season, episode=episode)

    # Pattern 3: E01, E001, etc. (single season shows)
    match = PATTERN_EXX.search(filename)
    if match:
        season = 1  # Default to season 1
        episode = int(match.group(1))
        return EpisodeInfo(season=season, episode=episode)

    # Fallback: try anime pattern even if not in anime mode
    if not anime_mode:
        match = PATTERN_ANIME.search(filename)
        if match:
            season = 1
            episode = int(match.group(1))
            return EpisodeInfo(season=season, episode=episode)

    return None


def detect_series_name(base_path: Path) -> str:
    """
    Auto-detect series name from folder structure.

    Handles:
    - Direct show folders: "Breaking Bad (2008)/"
    - Season subfolders: "Breaking Bad (2008)/Season 1/"
    - Specials folders: "Breaking Bad (2008)/Specials/"

    Args:
        base_path: Path to the directory being processed

    Returns:
        Cleaned series name (may include year in parentheses)
    """
    parent_name = base_path.name

    # Check if we're in a Season/season folder
    if re.match(r'^[Ss]eason\s*\d+$', parent_name) or re.match(r'^[Ss]\d+$', parent_name):
        # Go up one level for series name
        parent_name = base_path.parent.name

    # Check for Specials folder
    if re.match(r'^[Ss]pecials?$', parent_name):
        parent_name = base_path.parent.name

    clean_name = parent_name

    # Remove season indicators but keep year
    clean_name = re.sub(r'\s*-\s*[Ss]eason.*$', '', clean_name)
    clean_name = re.sub(r'\s*[Ss]\d+.*$', '', clean_name)

    # Clean up dots, underscores, normalize spacing
    clean_name = re.sub(r'[._]', ' ', clean_name)
    clean_name = re.sub(r'\s+', ' ', clean_name)
    clean_name = clean_name.strip()

    return clean_name


def detect_series_name_no_year(base_path: Path) -> str:
    """
    Auto-detect series name without year suffix.

    Args:
        base_path: Path to the directory being processed

    Returns:
        Cleaned series name without year
    """
    clean_name = detect_series_name(base_path)

    # Remove year patterns
    clean_name = re.sub(r'\s*\(2\d{3}\).*$', '', clean_name)
    clean_name = re.sub(r'\s*\(19\d{2}\).*$', '', clean_name)
    clean_name = re.sub(r'\s*\[\d{4}\].*$', '', clean_name)
    clean_name = clean_name.strip()

    return clean_name


def normalize_text(text: str) -> str:
    """
    Normalize text for comparison (lowercase, alphanumeric only).

    Used for fuzzy matching series names and titles.
    """
    return re.sub(r'[^a-z0-9]', '', text.lower())
