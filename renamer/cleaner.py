"""
Title cleaning and metadata stripping.

This module handles the complex task of extracting clean episode titles
from messy filenames containing quality indicators, codec info, release
groups, and other technical metadata.

The key insight: find the "boundary" between meaningful title content
and technical metadata, then clean everything appropriately.
"""

from __future__ import annotations

import re
from dataclasses import dataclass


# =============================================================================
# TECHNICAL METADATA PATTERNS
# These indicate the start of "junk" that should be stripped
# =============================================================================

# Quality indicators (resolution)
QUALITY_PATTERN = re.compile(
    r'[.\s_-]+(720p|1080p|2160p|4K|480p|576p)',
    re.IGNORECASE
)

# Codec indicators
CODEC_PATTERN = re.compile(
    r'[.\s_-]+(x264|x265|HEVC|H\.?264|H\.?265|AV1)',
    re.IGNORECASE
)

# Source indicators
SOURCE_PATTERN = re.compile(
    r'[.\s_-]+(WEB-DL|WEBRip|BluRay|BDRip|DVDRip|HDTV|PDTV|WEB)',
    re.IGNORECASE
)

# Platform indicators
PLATFORM_PATTERN = re.compile(
    r'[.\s_-]+(AMZN|NFLX|NF|HULU|DSNP|HBO|MAX|HMAX|ATVP|PMTP)',
    re.IGNORECASE
)

# Audio indicators
AUDIO_PATTERN = re.compile(
    r'[.\s_-]+(AAC|AC3|DTS|DDP\d?\.?\d?|EAC3|FLAC|TrueHD|Atmos)',
    re.IGNORECASE
)

# Release group pattern (at end of filename, after dash)
# Match: -KILLERS, -LOL, -YTS, -DIMENSION, etc.
# Only match ALLCAPS or contains digits (to avoid catching real words)
RELEASE_GROUP_PATTERN = re.compile(
    r'-([A-Z0-9]{3,}|[A-Za-z0-9]*\d[A-Za-z0-9]*)$'
)

# Common tags to remove (as whole words)
COMMON_TAGS = re.compile(
    r'\b(FIXED|REPACK|PROPER|INTERNAL|EXTENDED|UNCUT|DIRECTORS|CUT|DUBBED|SUBBED)\b',
    re.IGNORECASE
)

# Bracket content (usually metadata)
BRACKET_PATTERN = re.compile(r'\[[^\]]*\]')

# Technical parenthetical content
TECH_PAREN_PATTERN = re.compile(
    r'\([^)]*(?:720p|1080p|2160p|4K|x264|x265|HEVC|BluRay|WEB|HDTV)[^)]*\)',
    re.IGNORECASE
)

# Meaningful parenthetical content to PRESERVE
# Note: Use [\s._]+ to match dots/underscores since normalization happens later
MEANINGFUL_PAREN = re.compile(
    r'\((Part[\s._]+\d+|\d+|Extended[\s._]+Cut|Director\'?s?[\s._]+Cut|Final[\s._]+Cut|Unrated|Theatrical)\)',
    re.IGNORECASE
)

# WEB followed by codec (e.g., .WEB.x264)
WEB_CODEC_PATTERN = re.compile(
    r'\.WEB\.(x264|x265|HEVC|H\.?264|H\.?265|AAC|AC3|DTS|10bit|1080p|720p|2160p)',
    re.IGNORECASE
)

# Ellipsis placeholder for preservation
ELLIPSIS_PLACEHOLDER = "THREEDOTSPLACEHOLDER"


@dataclass
class CleanedTitle:
    """Result of title cleaning."""
    title: str
    was_cleaned: bool


def protect_ellipsis(text: str) -> str:
    """Replace ... with placeholder to protect during cleaning."""
    return text.replace("...", ELLIPSIS_PLACEHOLDER)


def restore_ellipsis(text: str) -> str:
    """Restore ... from placeholder."""
    return text.replace(ELLIPSIS_PLACEHOLDER, "...")


def find_title_boundary(text: str) -> int | None:
    """
    Find the index where the title ends and technical metadata begins.

    Returns the index of the first character of technical metadata,
    or None if no clear boundary is found.
    """
    # Protect ellipsis first
    text = protect_ellipsis(text)

    # Try each boundary pattern in order of reliability
    patterns = [
        # Quality with dot separator (most reliable)
        (r'^(.+)\.(720p|1080p|2160p|4K|480p|576p)', 1),
        # Quality with space and parenthesis
        (r'^(.+)\s+\((720p|1080p|2160p|4K|480p|576p)', 1),
        # WEB+codec pattern
        (r'^(.+)\.WEB\.(x264|x265|HEVC|H\.?264|H\.?265)', 1),
        # Technical indicators with dot
        (r'^(.+)\.(WEB-DL|BluRay|BDRip|HDTV|x264|x265|HEVC)', 1),
        # Technical with space and parenthesis
        (r'^(.+)\s+\((WEB-DL|BluRay|BDRip|HDTV|x264|x265|HEVC)', 1),
        # Platform indicators
        (r'^(.+)\.(AMZN|NFLX|NF|HULU)', 1),
    ]

    for pattern, group_idx in patterns:
        match = re.match(pattern, text, re.IGNORECASE)
        if match:
            return len(match.group(group_idx))

    return None


def clean_title(title: str, series_name: str = "") -> str:
    """
    Clean an episode title by removing technical metadata.

    This is the main entry point for title cleaning. It:
    1. Removes series name from the beginning
    2. Finds the boundary between title and metadata
    3. Strips quality, codec, source, and other indicators
    4. Preserves meaningful content like "(Part 1)" or ellipsis

    Args:
        title: The raw title string to clean
        series_name: Optional series name to strip from beginning

    Returns:
        Cleaned title string
    """
    if not title:
        return ""

    # Protect ellipsis
    title = protect_ellipsis(title)

    # Remove series name if provided
    if series_name:
        title = _remove_series_name(title, series_name)

    # Try to find a clean boundary
    boundary = find_title_boundary(title)
    if boundary and boundary > 2:
        title = title[:boundary]

    # Remove technical metadata that might have survived
    title = _strip_technical_metadata(title)

    # Remove release groups
    title = RELEASE_GROUP_PATTERN.sub('', title)

    # Remove common tags
    title = COMMON_TAGS.sub('', title)

    # Remove bracket content
    title = BRACKET_PATTERN.sub('', title)

    # Remove technical parenthetical content, but protect meaningful ones
    title = _clean_parentheticals(title)

    # Remove file extensions
    title = re.sub(r'\.(mkv|mp4|avi|m4v|mov|wmv|flv|webm|ts|m2ts)$', '', title, flags=re.IGNORECASE)

    # Normalize spacing and punctuation
    title = re.sub(r'[._]', ' ', title)
    title = re.sub(r'\s+', ' ', title)
    title = title.strip()
    title = title.strip('-').strip()

    # Restore ellipsis
    title = restore_ellipsis(title)

    return title


def _remove_series_name(title: str, series_name: str) -> str:
    """Remove series name from beginning of title."""
    # Get series name without year
    series_no_year = re.sub(r'\s*\(\d{4}\)', '', series_name)

    # Create variations for matching
    variations = [
        series_no_year,
        series_no_year.replace(' ', '.'),
        series_no_year.replace(' ', '-'),
        series_no_year.replace(' ', '_'),
    ]

    for variant in variations:
        # Escape for regex
        escaped = re.escape(variant)
        # Remove from beginning with optional year and separator
        # Handle both bare years (Doctor.Who.2005) and parenthesized years (Pluribus (2025))
        # Use (?!p) negative lookahead to avoid matching "1080" from "1080p" as a year
        # Note: In character classes, put - at end to avoid range interpretation
        title = re.sub(f'^{escaped}[.\\s_-]*\\(\\d{{4}}\\)[.\\s_-]*', '', title, flags=re.IGNORECASE)
        title = re.sub(f'^{escaped}[.\\s_-]*\\d{{4}}(?!p)[._-]*', '', title, flags=re.IGNORECASE)
        title = re.sub(f'^{escaped}[._-]*', '', title, flags=re.IGNORECASE)

    # Clean up any remaining year at start (with optional leading whitespace)
    title = re.sub(r'^\s*\(\d{4}\)\s*-?\s*', '', title)
    title = re.sub(r'^-\s*-\s*', '', title)

    return title


def _strip_technical_metadata(title: str) -> str:
    """Strip technical metadata patterns from title."""
    # Order matters: more specific patterns first

    # Quality indicators at end
    title = re.sub(r'[.\s_-]+(720p|1080p|2160p|4K|480p|576p)([.\s_-].*)?$', '', title, flags=re.IGNORECASE)

    # Codec indicators at end
    title = re.sub(r'[.\s_-]+(x264|x265|HEVC|H\.?264|H\.?265)([.\s_-].*)?$', '', title, flags=re.IGNORECASE)

    # Source indicators at end
    title = re.sub(r'[.\s_-]+(WEB-DL|WEBRip|BluRay|BDRip|DVDRip|HDTV|PDTV)([.\s_-].*)?$', '', title, flags=re.IGNORECASE)

    # WEB alone when followed by technical indicator (but not alone)
    title = re.sub(r'[.\s_-]+WEB[.\s_-]+(x264|x265|HEVC|AAC|AC3)([.\s_-].*)?$', '', title, flags=re.IGNORECASE)

    # Platform indicators at end
    title = re.sub(r'[.\s_-]+(AMZN|NFLX|NF|HULU|DSNP|HBO|MAX|HMAX)([.\s_-].*)?$', '', title, flags=re.IGNORECASE)

    # Audio indicators at end
    title = re.sub(r'[.\s_-]+(AAC|AC3|DTS|DDP\d?\.?\d?)([.\s_-].*)?$', '', title, flags=re.IGNORECASE)

    # DL abbreviation
    title = re.sub(r'(^|[.\s_-])(DL|DDP?)([.\s_-]|$)', r'\1\3', title, flags=re.IGNORECASE)

    # Technical abbreviations at start (when title is ONLY metadata)
    if re.match(r'^(720p|1080p|2160p|4K|WEB|BluRay|HDTV|x264|x265|HEVC)', title, re.IGNORECASE):
        return ""

    return title


def _clean_parentheticals(title: str) -> str:
    """Remove technical parentheticals while preserving meaningful ones."""
    # First, protect meaningful parentheticals
    protected = {}
    counter = 0

    for match in MEANINGFUL_PAREN.finditer(title):
        placeholder = f"__PROT_{counter}__"
        protected[placeholder] = match.group(0)
        title = title.replace(match.group(0), placeholder)
        counter += 1

    # Remove technical parentheticals
    title = TECH_PAREN_PATTERN.sub('', title)

    # Remove any remaining trailing parentheticals (usually technical)
    title = re.sub(r'\s*\([^)]*\)$', '', title)

    # Handle unclosed parenthesis at end
    title = re.sub(r'\s*\([^)]*$', '', title)

    # Restore protected content
    for placeholder, original in protected.items():
        title = title.replace(placeholder, original)

    return title


def validate_episode_title(
    candidate: str,
    series_name: str,
    season: int,
    episode: int,
    seen_titles: set[str] | None = None,
) -> str:
    """
    Validate and potentially reject a candidate episode title.

    Rejects titles that:
    - Are blank
    - Match or contain the series name
    - Look like generic episode references ("Episode 1", "01", etc.)
    - Are duplicates within the same season

    Args:
        candidate: The candidate title to validate
        series_name: The series name for comparison
        season: Season number (for dedup tracking)
        episode: Episode number (for dedup tracking)
        seen_titles: Optional set of already-seen normalized titles

    Returns:
        The title if valid, empty string if rejected
    """
    if not candidate or not candidate.strip():
        return ""

    title = candidate.strip()

    # Normalize for comparison
    def normalize(s: str) -> str:
        return re.sub(r'[^a-z0-9]', '', s.lower())

    norm_title = normalize(title)
    norm_series = normalize(series_name)

    # Get series without year
    series_no_year = re.sub(r'\s*\(\d{4}\)', '', series_name)
    norm_series_no_year = normalize(series_no_year)

    # Reject if title matches or is contained in series name
    if norm_title == norm_series:
        return ""
    if norm_title == norm_series_no_year:
        return ""
    if norm_series_no_year and norm_series_no_year in norm_title:
        return ""
    if norm_title and norm_title in norm_series_no_year:
        return ""

    # Reject generic episode references
    if re.match(r'^(episode|ep)?0*\d+$', norm_title):
        return ""

    # Deduplicate within season
    if seen_titles is not None:
        dedup_key = f"{season}_{norm_title}"
        if dedup_key in seen_titles:
            return ""
        seen_titles.add(dedup_key)

    return title
