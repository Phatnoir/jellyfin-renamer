"""
File operations for media renaming.

Handles safe file renaming, companion file management, and filesystem
edge cases (like case-insensitive renames on Windows/macOS).
"""

from __future__ import annotations

import os
import shutil
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

from .parser import EpisodeInfo, detect_series_name, detect_series_name_no_year, get_season_episode
from .cleaner import clean_title, validate_episode_title


# =============================================================================
# OUTPUT FORMATS
# =============================================================================

class OutputFormat:
    """Available output filename formats."""
    SHOW_YEAR_SXXEXX_TITLE = "Show (Year) - SxxExx - Title"
    SHOW_YEAR_SXXEXX = "Show (Year) - SxxExx"
    SHOW_SXXEXX_TITLE = "Show - SxxExx - Title"
    SHOW_SXXEXX = "Show - SxxExx"
    SXXEXX_TITLE = "SxxExx - Title"
    SXXEXX = "SxxExx"

    @classmethod
    def all_formats(cls) -> list[str]:
        return [
            cls.SHOW_YEAR_SXXEXX_TITLE,
            cls.SHOW_YEAR_SXXEXX,
            cls.SHOW_SXXEXX_TITLE,
            cls.SHOW_SXXEXX,
            cls.SXXEXX_TITLE,
            cls.SXXEXX,
        ]


# Video and subtitle extensions
VIDEO_EXTENSIONS = {'.mkv', '.mp4', '.avi', '.m4v', '.mov', '.wmv', '.flv', '.webm', '.ts', '.m2ts'}
SUBTITLE_EXTENSIONS = {'.srt', '.sub', '.ass', '.ssa', '.vtt'}
COMPANION_EXTENSIONS = {'.srt', '.ass', '.vtt', '.ssa', '.sub', '.idx', '.nfo', '.jpg', '.jpeg', '.png', '.ttml', '.txt', '.sfv', '.srr', '.tbn', '.cue', '.xml', '.mka', '.mks'}


@dataclass
class RenameResult:
    """Result of a rename operation."""
    old_path: Path
    new_path: Path
    success: bool
    skipped: bool = False
    message: str = ""


@dataclass
class RenameOptions:
    """Options for rename operations."""
    dry_run: bool = False
    force: bool = False
    verbose: bool = False
    anime_mode: bool = False
    deep_clean: bool = False
    output_format: str = OutputFormat.SHOW_SXXEXX_TITLE
    series_name: str | None = None

    # Callbacks for output (allows CLI to hook in)
    on_status: Callable[[str, str], None] | None = None  # (color, message)
    on_verbose: Callable[[str], None] | None = None
    on_result: Callable[["RenameResult"], None] | None = None  # Called after each file


@dataclass
class RenameSession:
    """Tracks state across a rename session."""
    base_path: Path
    options: RenameOptions
    series_name: str = ""
    seen_titles: set[str] = field(default_factory=set)
    results: list[RenameResult] = field(default_factory=list)

    def __post_init__(self):
        # Helper for verbose output
        def verbose(msg: str) -> None:
            if self.options.on_verbose:
                self.options.on_verbose(msg)

        # Auto-detect series name if not provided
        if self.options.series_name:
            self.series_name = self.options.series_name
            verbose(f"Using provided series name: '{self.series_name}'")
        else:
            self.series_name = detect_series_name(self.base_path)
            verbose(f"Auto-detected series name: '{self.series_name}'")


def build_filename(
    episode_info: EpisodeInfo,
    title: str | None,
    extension: str,
    series_name: str,
    output_format: str,
    base_path: Path,
) -> str:
    """
    Build the output filename based on format string.

    Args:
        episode_info: Parsed season/episode info
        title: Episode title (may be None or empty)
        extension: File extension (without dot)
        series_name: Series name (may include year)
        output_format: One of the OutputFormat constants
        base_path: Base path for series name detection

    Returns:
        Formatted filename
    """
    season_episode = episode_info.format_code()

    # Get series name without year for certain formats
    series_no_year = detect_series_name_no_year(base_path) if series_name else ""

    match output_format:
        case OutputFormat.SHOW_YEAR_SXXEXX_TITLE:
            if title and series_name:
                return f"{series_name} - {season_episode} - {title}.{extension}"
            elif series_name:
                return f"{series_name} - {season_episode}.{extension}"
            elif title:
                return f"{season_episode} - {title}.{extension}"
            else:
                return f"{season_episode}.{extension}"

        case OutputFormat.SHOW_YEAR_SXXEXX:
            if series_name:
                return f"{series_name} - {season_episode}.{extension}"
            else:
                return f"{season_episode}.{extension}"

        case OutputFormat.SHOW_SXXEXX_TITLE:
            if title and series_no_year:
                return f"{series_no_year} - {season_episode} - {title}.{extension}"
            elif series_no_year:
                return f"{series_no_year} - {season_episode}.{extension}"
            elif title:
                return f"{season_episode} - {title}.{extension}"
            else:
                return f"{season_episode}.{extension}"

        case OutputFormat.SHOW_SXXEXX:
            if series_no_year:
                return f"{series_no_year} - {season_episode}.{extension}"
            else:
                return f"{season_episode}.{extension}"

        case OutputFormat.SXXEXX_TITLE:
            if title:
                return f"{season_episode} - {title}.{extension}"
            else:
                return f"{season_episode}.{extension}"

        case OutputFormat.SXXEXX:
            return f"{season_episode}.{extension}"

        case _:
            # Default fallback
            if title and series_name:
                return f"{series_name} - {season_episode} - {title}.{extension}"
            elif series_name:
                return f"{series_name} - {season_episode}.{extension}"
            else:
                return f"{season_episode}.{extension}"


def is_case_only_rename(old_path: Path, new_path: Path) -> bool:
    """Check if this is a case-only rename on a case-insensitive filesystem."""
    return (
        old_path != new_path and
        str(old_path).lower() == str(new_path).lower()
    )


def safe_rename(
    old_path: Path,
    new_path: Path,
    dry_run: bool = False,
    force: bool = False,
) -> RenameResult:
    """
    Safely rename a file with collision and permission handling.

    Handles:
    - Case-only renames on case-insensitive filesystems (two-step rename)
    - Collision detection (skip or force overwrite)
    - Permission fixes for read-only files

    Args:
        old_path: Source file path
        new_path: Destination file path
        dry_run: If True, don't actually rename
        force: If True, overwrite existing files

    Returns:
        RenameResult with success/failure info
    """
    # Source doesn't exist
    if not old_path.exists():
        return RenameResult(
            old_path=old_path,
            new_path=new_path,
            success=False,
            message=f"Source doesn't exist: {old_path}",
        )

    # Already has correct name
    if old_path == new_path:
        return RenameResult(
            old_path=old_path,
            new_path=new_path,
            success=True,
            skipped=True,
            message="Already correct",
        )

    # Check for collision
    if new_path.exists() and not is_case_only_rename(old_path, new_path):
        if not force:
            return RenameResult(
                old_path=old_path,
                new_path=new_path,
                success=False,
                skipped=True,
                message=f"Destination exists: {new_path.name}",
            )

    if dry_run:
        return RenameResult(
            old_path=old_path,
            new_path=new_path,
            success=True,
            message="Would rename",
        )

    try:
        # Fix permissions if needed
        if not os.access(old_path, os.W_OK):
            try:
                old_path.chmod(old_path.stat().st_mode | 0o200)
            except OSError:
                pass

        # Handle case-only renames with two-step process
        if is_case_only_rename(old_path, new_path):
            tmp_path = new_path.with_suffix(new_path.suffix + ".__tmp__")
            old_path.rename(tmp_path)
            tmp_path.rename(new_path)
        else:
            old_path.rename(new_path)

        return RenameResult(
            old_path=old_path,
            new_path=new_path,
            success=True,
            message="Renamed",
        )

    except OSError as e:
        return RenameResult(
            old_path=old_path,
            new_path=new_path,
            success=False,
            message=f"Rename failed: {e}",
        )


def rename_companions(
    old_video: Path,
    new_video: Path,
    dry_run: bool = False,
) -> list[RenameResult]:
    """
    Rename companion files (subtitles, NFO, artwork) to match video.

    Preserves language codes and other suffixes (e.g., .en.srt stays .en.srt).

    Args:
        old_video: Original video path
        new_video: New video path
        dry_run: If True, don't actually rename

    Returns:
        List of RenameResults for each companion file
    """
    results = []

    old_base = old_video.stem
    new_base = new_video.stem
    directory = old_video.parent

    for path in directory.iterdir():
        # Skip the video file itself
        if path == old_video:
            continue

        # Only process whitelisted extensions
        if path.suffix.lower() not in COMPANION_EXTENSIONS:
            continue

        # Must start with old video base name
        if not path.name.startswith(old_base):
            continue

        # Preserve suffix after base name (language codes, etc.)
        suffix = path.name[len(old_base):]
        new_name = f"{new_base}{suffix}"
        new_path = directory / new_name

        result = safe_rename(path, new_path, dry_run=dry_run)
        results.append(result)

    return results


def get_episode_title(
    filename: str,
    episode_info: EpisodeInfo,
    series_name: str,
    seen_titles: set[str] | None = None,
) -> str:
    """
    Extract and clean episode title from filename.

    This is a simplified version that delegates to cleaner.py.
    The full Bash version has more complex boundary detection.

    Args:
        filename: Original filename
        episode_info: Parsed episode info
        series_name: Series name for removal
        seen_titles: Set of seen titles for deduplication

    Returns:
        Cleaned episode title, or empty string if none found
    """
    import re

    # Remove extension
    title = Path(filename).stem

    # Remove episode pattern from title
    # S01E01 pattern
    title = re.sub(r'[Ss]\d{1,2}[\s_.-]*[Ee]\d{1,3}[\s_.-]*', '', title)
    # NxNN pattern
    title = re.sub(r'\d{1,2}x\d{2,3}[\s_.-]*', '', title)
    # E## pattern
    title = re.sub(r'[Ee]\d{1,3}[\s_.-]*', '', title)
    # Anime pattern
    title = re.sub(r'-\s*\d{1,3}\s*(?=[\[\(.])', '', title)

    # Clean the title
    title = clean_title(title, series_name)

    # Validate (removes duplicates, series name matches, etc.)
    title = validate_episode_title(
        title,
        series_name,
        episode_info.season,
        episode_info.episode,
        seen_titles,
    )

    return title


def _episode_sort_key(path: Path) -> tuple:
    """
    Generate a sort key for episode files.

    Sorts by: (parent_path, season, episode, lowercase_name)
    This ensures files are grouped by directory, then ordered by episode number,
    regardless of filename case.
    """
    episode_info = get_season_episode(path.name)
    if episode_info:
        return (str(path.parent).lower(), episode_info.season, episode_info.episode, path.name.lower())
    # Fallback for non-episode files: sort by path, then name
    return (str(path.parent).lower(), 999, 999, path.name.lower())


def find_video_files(base_path: Path) -> list[Path]:
    """Find all video files in directory tree."""
    files = []
    for ext in VIDEO_EXTENSIONS:
        files.extend(base_path.rglob(f"*{ext}"))
        files.extend(base_path.rglob(f"*{ext.upper()}"))
    return sorted(set(files), key=_episode_sort_key)


def find_subtitle_files(base_path: Path) -> list[Path]:
    """Find all subtitle files in directory tree."""
    files = []
    for ext in SUBTITLE_EXTENSIONS:
        files.extend(base_path.rglob(f"*{ext}"))
        files.extend(base_path.rglob(f"*{ext.upper()}"))
    return sorted(set(files), key=_episode_sort_key)


def process_video_file(
    file_path: Path,
    session: RenameSession,
) -> RenameResult | None:
    """
    Process a single video file for renaming.

    Args:
        file_path: Path to video file
        session: Current rename session with options and state

    Returns:
        RenameResult if processed, None if skipped
    """
    filename = file_path.name
    extension = file_path.suffix.lstrip('.')

    # Helper for verbose output
    def verbose(msg: str) -> None:
        if session.options.on_verbose:
            session.options.on_verbose(msg)

    verbose(f"Processing file: {filename}")

    # Extract episode info
    episode_info = get_season_episode(filename, anime_mode=session.options.anime_mode)
    if not episode_info:
        verbose(f"Could not extract episode info")
        return RenameResult(
            old_path=file_path,
            new_path=file_path,
            success=False,
            message=f"Could not extract episode info from: {filename}",
        )

    verbose(f"Extracted season/episode: {episode_info.format_code()}")

    # Handle Specials folder - override season to 00
    if file_path.parent.name.lower() in ('specials', 'special'):
        episode_info = EpisodeInfo(season=0, episode=episode_info.episode)
        verbose(f"Specials folder detected, using Season 00")

    # Get episode title
    title = get_episode_title(
        filename,
        episode_info,
        session.series_name,
        session.seen_titles,
    )

    if title:
        verbose(f"Extracted episode title: '{title}'")
    else:
        verbose(f"No episode title extracted")

    # Build new filename
    new_filename = build_filename(
        episode_info,
        title if title else None,
        extension,
        session.series_name,
        session.options.output_format,
        session.base_path,
    )
    new_path = file_path.parent / new_filename

    verbose(f"Formatted filename: '{new_filename}'")

    # Perform rename
    result = safe_rename(
        file_path,
        new_path,
        dry_run=session.options.dry_run,
        force=session.options.force,
    )

    # Rename companions if successful (including for "Already correct" files)
    # Bash script handles companions for both renamed and already-correct files
    if result.success:
        companion_results = rename_companions(
            file_path,
            new_path,
            dry_run=session.options.dry_run,
        )
        # Print companion results like bash script does
        for comp_result in companion_results:
            if comp_result.success and not comp_result.skipped:
                if session.options.dry_run:
                    verbose(f"[DRY] Would rename sidecar: {comp_result.old_path.name} → {comp_result.new_path.name}")
                else:
                    verbose(f"Renamed sidecar: {comp_result.old_path.name} → {comp_result.new_path.name}")

    # Call result callback immediately so output is interspersed with verbose
    if session.options.on_result:
        session.options.on_result(result)

    return result


def process_directory(
    base_path: Path,
    options: RenameOptions,
) -> list[RenameResult]:
    """
    Process all video files in a directory.

    Args:
        base_path: Directory to process
        options: Rename options

    Returns:
        List of all rename results
    """
    session = RenameSession(base_path=base_path, options=options)

    # Find and process video files
    video_files = find_video_files(base_path)

    for file_path in video_files:
        result = process_video_file(file_path, session)
        if result:
            session.results.append(result)

    return session.results
