"""
Internal metadata cleaning for video files.

Wraps mkvpropedit (for MKV) and ffmpeg (for MP4) to clean internal
metadata like container titles and track names that can show up
in media server interfaces.
"""

from __future__ import annotations

import re
import shutil
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path


@dataclass
class MetadataResult:
    """Result of a metadata cleaning operation."""
    file_path: Path
    success: bool
    changed: bool = False
    message: str = ""


def has_mkvpropedit() -> bool:
    """Check if mkvpropedit is available."""
    return shutil.which("mkvpropedit") is not None


def has_mkvmerge() -> bool:
    """Check if mkvmerge is available."""
    return shutil.which("mkvmerge") is not None


def has_ffmpeg() -> bool:
    """Check if ffmpeg is available."""
    return shutil.which("ffmpeg") is not None


def has_mediainfo() -> bool:
    """Check if mediainfo is available."""
    return shutil.which("mediainfo") is not None


def get_mkv_track_ids(file_path: Path) -> list[int]:
    """
    Get track IDs from an MKV file using mkvmerge.

    Returns:
        List of track IDs, empty if mkvmerge not available or error
    """
    if not has_mkvmerge():
        return []

    try:
        result = subprocess.run(
            ["mkvmerge", "-i", str(file_path)],
            capture_output=True,
            text=True,
            timeout=30,
        )
        # Parse: "Track ID 0: video ..." -> extract 0
        track_ids = []
        for match in re.finditer(r"Track ID (\d+):", result.stdout):
            track_ids.append(int(match.group(1)))
        return track_ids
    except (subprocess.TimeoutExpired, subprocess.SubprocessError):
        return []


def get_mp4_title(file_path: Path) -> str:
    """
    Get current title metadata from MP4 file using mediainfo.

    Returns:
        Current title, or empty string if not available
    """
    if not has_mediainfo():
        return ""

    try:
        result = subprocess.run(
            ["mediainfo", "--Output=General;%Title%", str(file_path)],
            capture_output=True,
            text=True,
            timeout=30,
        )
        title = result.stdout.strip()
        # Normalize N/A responses
        if title.lower() in ("n/a", "na", "none", ""):
            return ""
        # Strip surrounding quotes
        if (title.startswith('"') and title.endswith('"')) or \
           (title.startswith("'") and title.endswith("'")):
            title = title[1:-1]
        return title
    except (subprocess.TimeoutExpired, subprocess.SubprocessError):
        return ""


def clean_mkv_metadata(
    file_path: Path,
    clean_title: str,
    dry_run: bool = False,
) -> MetadataResult:
    """
    Clean internal metadata from MKV file.

    Uses mkvpropedit to:
    - Set container title
    - Clear global tags
    - Clear individual track names

    Args:
        file_path: Path to MKV file
        clean_title: Title to set (usually clean filename without extension)
        dry_run: If True, don't make changes

    Returns:
        MetadataResult with success/failure info
    """
    if not has_mkvpropedit():
        return MetadataResult(
            file_path=file_path,
            success=False,
            message="mkvpropedit not found",
        )

    if dry_run:
        return MetadataResult(
            file_path=file_path,
            success=True,
            changed=True,
            message="Would clean MKV metadata",
        )

    try:
        # Step 1: Set container title and clear tags
        result = subprocess.run(
            [
                "mkvpropedit", "--quiet",
                "--edit", "info", "--set", f"title={clean_title}",
                "--tags", "all:",
                str(file_path),
            ],
            capture_output=True,
            text=True,
            timeout=60,
        )

        if result.returncode != 0:
            return MetadataResult(
                file_path=file_path,
                success=False,
                message=f"mkvpropedit failed: {result.stderr}",
            )

        # Step 2: Clear track names
        track_ids = get_mkv_track_ids(file_path)
        for track_id in track_ids:
            # Use --delete name to remove track name
            # Exit code 2 means property doesn't exist (not an error)
            subprocess.run(
                [
                    "mkvpropedit", "--quiet",
                    str(file_path),
                    "--edit", f"track:@{track_id}",
                    "--delete", "name",
                ],
                capture_output=True,
                timeout=30,
            )

        return MetadataResult(
            file_path=file_path,
            success=True,
            changed=True,
            message="Cleaned MKV metadata",
        )

    except subprocess.TimeoutExpired:
        return MetadataResult(
            file_path=file_path,
            success=False,
            message="mkvpropedit timed out",
        )
    except subprocess.SubprocessError as e:
        return MetadataResult(
            file_path=file_path,
            success=False,
            message=f"mkvpropedit error: {e}",
        )


def title_needs_cleaning(current_title: str, clean_title: str) -> bool:
    """
    Check if MP4 title needs cleaning.

    Returns True if current title contains technical metadata.
    """
    if not current_title:
        return False

    if current_title == clean_title:
        return False

    # Normalize for comparison
    norm_current = re.sub(r'[^a-z0-9]', '', current_title.lower())
    norm_clean = re.sub(r'[^a-z0-9]', '', clean_title.lower())

    # Check for technical indicators
    tech_indicators = [
        '720p', '1080p', '2160p', '4k',
        'x264', 'x265', 'hevc', 'h264', 'h265',
        'web', 'webrip', 'webdl', 'bluray', 'hdtv',
        'aac', 'ac3', 'dts',
    ]

    for indicator in tech_indicators:
        if indicator in norm_current:
            return True

    # Different from expected clean format
    if norm_current != norm_clean and not norm_clean.startswith(norm_current):
        return True

    return False


def clean_mp4_metadata(
    file_path: Path,
    clean_title: str,
    dry_run: bool = False,
) -> MetadataResult:
    """
    Clean internal metadata from MP4 file.

    Uses ffmpeg to remux with clean metadata. Only processes files
    that have technical metadata in their title.

    Args:
        file_path: Path to MP4 file
        clean_title: Title to set
        dry_run: If True, don't make changes

    Returns:
        MetadataResult with success/failure info
    """
    if not has_ffmpeg():
        return MetadataResult(
            file_path=file_path,
            success=False,
            message="ffmpeg not found",
        )

    # Check current title
    current_title = get_mp4_title(file_path)

    # Skip if already clean
    if not title_needs_cleaning(current_title, clean_title):
        return MetadataResult(
            file_path=file_path,
            success=True,
            changed=False,
            message="MP4 metadata already clean",
        )

    if dry_run:
        return MetadataResult(
            file_path=file_path,
            success=True,
            changed=True,
            message=f"Would clean MP4 metadata (current: '{current_title}')",
        )

    try:
        # Create temp file in same directory to avoid cross-device move issues
        temp_path = file_path.with_suffix(f".tmp{file_path.suffix}")

        # ffmpeg: copy all streams, clear metadata, set title
        result = subprocess.run(
            [
                "ffmpeg", "-hide_banner", "-nostdin", "-v", "error",
                "-i", str(file_path),
                "-map", "0",
                "-c", "copy",
                "-map_metadata", "-1",
                "-metadata", f"title={clean_title}",
                "-movflags", "use_metadata_tags",
                "-f", "mp4",
                "-y", str(temp_path),
            ],
            capture_output=True,
            text=True,
            timeout=300,  # 5 minutes for large files
        )

        if result.returncode != 0:
            temp_path.unlink(missing_ok=True)
            return MetadataResult(
                file_path=file_path,
                success=False,
                message=f"ffmpeg failed: {result.stderr}",
            )

        # Replace original with cleaned version
        temp_path.replace(file_path)

        return MetadataResult(
            file_path=file_path,
            success=True,
            changed=True,
            message="Cleaned MP4 metadata",
        )

    except subprocess.TimeoutExpired:
        temp_path.unlink(missing_ok=True)
        return MetadataResult(
            file_path=file_path,
            success=False,
            message="ffmpeg timed out",
        )
    except subprocess.SubprocessError as e:
        return MetadataResult(
            file_path=file_path,
            success=False,
            message=f"ffmpeg error: {e}",
        )
    except OSError as e:
        return MetadataResult(
            file_path=file_path,
            success=False,
            message=f"File operation error: {e}",
        )


def clean_metadata(
    file_path: Path,
    clean_title: str,
    dry_run: bool = False,
) -> MetadataResult:
    """
    Clean metadata from video file (auto-detects format).

    Args:
        file_path: Path to video file
        clean_title: Title to set
        dry_run: If True, don't make changes

    Returns:
        MetadataResult with success/failure info
    """
    suffix = file_path.suffix.lower()

    if suffix == ".mkv":
        return clean_mkv_metadata(file_path, clean_title, dry_run)
    elif suffix in (".mp4", ".m4v"):
        return clean_mp4_metadata(file_path, clean_title, dry_run)
    else:
        return MetadataResult(
            file_path=file_path,
            success=True,
            changed=False,
            message=f"Metadata cleaning not supported for {suffix}",
        )
