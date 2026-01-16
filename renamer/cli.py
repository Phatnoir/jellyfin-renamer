"""
Command-line interface for jellyfin-renamer.

Provides the same interface as the original Bash script:
  jellyfin-renamer [options] [path]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from . import __version__
from .operations import (
    OutputFormat,
    RenameOptions,
    RenameResult,
    find_video_files,
    find_subtitle_files,
    process_directory,
)
from .metadata import clean_metadata, has_mkvpropedit, has_ffmpeg


# =============================================================================
# COLORS (ANSI escape codes)
# =============================================================================

class Colors:
    RED = "\033[0;31m"
    GREEN = "\033[0;32m"
    YELLOW = "\033[1;33m"
    BLUE = "\033[0;34m"
    CYAN = "\033[0;36m"
    PURPLE = "\033[0;35m"
    NC = "\033[0m"  # No Color

    @classmethod
    def disable(cls):
        """Disable colors (for non-TTY output)."""
        cls.RED = ""
        cls.GREEN = ""
        cls.YELLOW = ""
        cls.BLUE = ""
        cls.CYAN = ""
        cls.PURPLE = ""
        cls.NC = ""


def print_status(color: str, message: str) -> None:
    """Print a colored status message."""
    print(f"{color}{message}{Colors.NC}")


def print_verbose(message: str, verbose: bool) -> None:
    """Print a verbose message if verbose mode is enabled."""
    if verbose:
        print(f"{Colors.CYAN}  [VERBOSE] {message}{Colors.NC}", file=sys.stderr)


# =============================================================================
# CLI ARGUMENT PARSING
# =============================================================================

def create_parser() -> argparse.ArgumentParser:
    """Create the argument parser with all options."""
    parser = argparse.ArgumentParser(
        prog="jellyfin-renamer",
        description="Universal Media Renamer for Jellyfin/Plex",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --dry-run .
  %(prog)s --series "Doctor Who (2005)" --dry-run /path/to/shows
  %(prog)s --format "Show (Year) - SxxExx - Title" --dry-run .
  %(prog)s --anime --dry-run /path/to/anime/show
  %(prog)s --anime --format "Show - SxxExx" --dry-run .

Supported Episode Patterns:
  Standard TV Shows:    S01E01, S1E1, 1x01, 01x01, E01, E001
  Anime/Fansub:         [Group] Show - 01 [Quality], Show - 01 [Metadata]
""",
    )

    parser.add_argument(
        "--version",
        action="version",
        version=f"%(prog)s {__version__}",
    )

    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be renamed without making changes",
    )

    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Show detailed processing information",
    )

    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing files (use with caution)",
    )

    parser.add_argument(
        "--anime",
        action="store_true",
        help="Enable anime/fansub mode (prioritizes anime naming patterns)",
    )

    parser.add_argument(
        "--deep-clean",
        action="store_true",
        help="Clean internal MKV/MP4 metadata and rename companion files",
    )

    parser.add_argument(
        "--series",
        metavar="NAME",
        help="Specify series name (auto-detected if not provided)",
    )

    parser.add_argument(
        "--format",
        metavar="FORMAT",
        default=OutputFormat.SHOW_SXXEXX_TITLE,
        choices=OutputFormat.all_formats(),
        help=f"Output format (default: '{OutputFormat.SHOW_SXXEXX_TITLE}')",
    )

    parser.add_argument(
        "path",
        nargs="?",
        default=".",
        help="Directory to process (default: current directory)",
    )

    return parser


# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

def main(argv: list[str] | None = None) -> int:
    """
    Main entry point for the CLI.

    Args:
        argv: Command-line arguments (defaults to sys.argv[1:])

    Returns:
        Exit code (0 for success, non-zero for errors)
    """
    parser = create_parser()
    args = parser.parse_args(argv)

    # Disable colors if not a TTY
    if not sys.stdout.isatty():
        Colors.disable()

    # Validate path
    base_path = Path(args.path).resolve()
    if not base_path.is_dir():
        print_status(Colors.RED, f'Error: Directory "{args.path}" does not exist!')
        return 1

    # Adjust default format for anime mode
    output_format = args.format
    if args.anime and args.format == OutputFormat.SHOW_SXXEXX_TITLE:
        output_format = OutputFormat.SHOW_SXXEXX

    # Create options
    options = RenameOptions(
        dry_run=args.dry_run,
        force=args.force,
        verbose=args.verbose,
        anime_mode=args.anime,
        deep_clean=args.deep_clean,
        output_format=output_format,
        series_name=args.series,
    )

    # Print header
    print_status(Colors.BLUE, "=== Universal Media Renamer - Python Edition ===")
    print_status(Colors.BLUE, f"Base path: {base_path}")
    print_status(Colors.BLUE, f"Output format: {output_format}")

    if args.series:
        print_status(Colors.BLUE, f"Series name: {args.series}")
    if args.dry_run:
        print_status(Colors.YELLOW, "DRY RUN MODE - No changes will be made")
    if args.verbose:
        print_status(Colors.CYAN, "VERBOSE MODE - Detailed output enabled")
    if args.force:
        print_status(Colors.YELLOW, "FORCE MODE - Will overwrite existing files")
    if args.deep_clean:
        print_status(Colors.PURPLE, "DEEP CLEAN MODE - Will clean metadata and rename companion files")
        if not has_mkvpropedit():
            print_status(Colors.YELLOW, "  Warning: mkvpropedit not found (MKV metadata cleaning disabled)")
        if not has_ffmpeg():
            print_status(Colors.YELLOW, "  Warning: ffmpeg not found (MP4 metadata cleaning disabled)")

    print()

    # Process files
    print_status(Colors.BLUE, "Processing episode files...")

    results = process_directory(base_path, options)

    # Print results
    renamed_count = 0
    for result in results:
        if result.success:
            if result.skipped:
                if "Already correct" in result.message:
                    print_status(Colors.GREEN, f"  Already correct: {result.new_path.name}")
                else:
                    print_status(Colors.YELLOW, f"  Skipped: {result.old_path.name} - {result.message}")
            else:
                if args.dry_run:
                    print_status(Colors.YELLOW, f"  [DRY] {result.old_path.name}{result.new_path.name}")
                else:
                    print_status(Colors.GREEN, f"  Renamed: {result.old_path.name}{result.new_path.name}")
                renamed_count += 1

                # Deep clean if requested
                if args.deep_clean and not args.dry_run:
                    clean_title = result.new_path.stem
                    meta_result = clean_metadata(result.new_path, clean_title, dry_run=args.dry_run)
                    if meta_result.changed:
                        print_status(Colors.GREEN, f"    Cleaned metadata: {result.new_path.name}")
        else:
            print_status(Colors.RED, f"  Error: {result.old_path.name} - {result.message}")

    # Summary
    video_count = len(find_video_files(base_path))
    subtitle_count = len(find_subtitle_files(base_path))

    print()
    print_status(Colors.BLUE, "=== Summary ===")
    print_status(Colors.GREEN, f"Total episode files: {video_count}")
    if subtitle_count > 0:
        print_status(Colors.GREEN, f"Total subtitle files: {subtitle_count}")

    if args.dry_run:
        print()
        print_status(Colors.YELLOW, "This was a dry run. To apply changes, run without --dry-run")
        print_status(Colors.YELLOW, "Review the proposed changes above before proceeding.")
    else:
        print()
        print_status(Colors.GREEN, "Renaming complete!")
        print_status(Colors.BLUE, "Your files should now be compatible with Jellyfin/Plex.")

    print_status(Colors.PURPLE, "Universal Media Renamer completed successfully!")

    return 0


if __name__ == "__main__":
    sys.exit(main())
