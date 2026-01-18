"""
Tests for title cleaning and full filename transformation.

These tests verify the complete pipeline: messy filename -> clean output.
"""

import pytest
from renamer.cleaner import clean_title
from renamer.parser import get_season_episode, EpisodeInfo
from renamer.operations import get_episode_title, build_filename
from pathlib import Path


class TestTitleCleaning:
    """Test title extraction from messy filenames."""

    @pytest.mark.parametrize("input_filename,expected_title", [
        # Quality boundary detection
        ("Pilot.720p.WEB-DL.x264-GROUP", "Pilot"),
        ("Title.Here.1080p.BluRay", "Title Here"),
        ("Multi.Word.Title.2160p.HEVC", "Multi Word Title"),

        # Technical metadata removal
        ("Title.WEB-DL.x264-KILLERS", "Title"),
        ("Title.HDTV.XviD-LOL", "Title"),
        ("Title.AMZN.WEB-DL.DDP5.1", "Title"),

        # Release group removal
        ("Title-DIMENSION", "Title"),
        ("Title-LOL", "Title"),
        ("Title-YTS", "Title"),

        # Preserve meaningful content
        ("What...", "What..."),
        ("Title.(Part.1).720p", "Title (Part 1)"),
    ])
    def test_clean_title(self, input_filename: str, expected_title: str):
        """Test that clean_title extracts the right title."""
        result = clean_title(input_filename)
        print(f'"{input_filename}" -> "{result}" (expected: "{expected_title}")')
        assert result == expected_title


class TestFullTransformation:
    """Test the complete filename transformation pipeline."""

    @pytest.mark.parametrize("input_filename,series_name,expected_output", [
        # Standard TV shows
        (
            "Breaking.Bad.S01E01.Pilot.720p.WEB-DL.x264-GROUP.mkv",
            "Breaking Bad (2008)",
            "Breaking Bad (2008) - S01E01 - Pilot.mkv"
        ),
        (
            "Doctor.Who.2005.S05E04.Time.Of.The.Angels.HDTV.XviD-FoV.avi",
            "Doctor Who (2005)",
            "Doctor Who (2005) - S05E04 - Time Of The Angels.avi"
        ),
        (
            "The.Office.S02E15.1080p.BluRay.mkv",
            "The Office (2005)",
            "The Office (2005) - S02E15.mkv"  # No title extracted
        ),

        # Already-renamed files with parenthesized year and quality in parens
        (
            "Pluribus (2025) - S01E01 - We Is Us (1080p ATVP WEB-DL x265 Ghost).mkv",
            "Pluribus (2025)",
            "Pluribus (2025) - S01E01 - We Is Us.mkv"
        ),

        # Anime (with anime mode)
        (
            "[Erai-raws] Cyberpunk - Edgerunners - 01 [1080p][Multiple Subtitle].mkv",
            "Cyberpunk Edgerunners (2022)",
            "Cyberpunk Edgerunners (2022) - S01E01.mkv"
        ),
    ])
    def test_full_transformation(
        self,
        input_filename: str,
        series_name: str,
        expected_output: str
    ):
        """Test the complete input -> output transformation."""
        # Determine if anime mode
        anime_mode = input_filename.startswith("[")

        # Parse episode
        episode_info = get_season_episode(input_filename, anime_mode=anime_mode)
        assert episode_info is not None, f"Failed to parse: {input_filename}"

        # Get title
        title = get_episode_title(
            input_filename,
            episode_info,
            series_name,
            seen_titles=set(),
        )

        # Build filename
        extension = Path(input_filename).suffix.lstrip('.')
        result = build_filename(
            episode_info,
            title if title else None,
            extension,
            series_name,
            "Show (Year) - SxxExx - Title",
            Path("/fake/path"),  # Not used for this format
        )

        print(f"{input_filename}")
        print(f"  -> {result}")
        print(f"  expected: {expected_output}")

        assert result == expected_output


class TestDefaultFormat:
    """Test with the default 'Show - SxxExx - Title' format (no year in output)."""

    def test_pluribus_default_format(self):
        """Real-world test: Pluribus files with default format."""
        from renamer.operations import OutputFormat

        input_filename = "Pluribus (2025) - S01E01 - We Is Us (1080p ATVP WEB-DL x265 Ghost).mkv"
        series_name = "Pluribus (2025)"
        expected_output = "Pluribus - S01E01 - We Is Us.mkv"

        episode_info = get_season_episode(input_filename)
        assert episode_info is not None

        title = get_episode_title(input_filename, episode_info, series_name, set())

        extension = Path(input_filename).suffix.lstrip('.')
        result = build_filename(
            episode_info,
            title if title else None,
            extension,
            series_name,
            OutputFormat.SHOW_SXXEXX_TITLE,  # Default format
            Path("/fake/Pluribus (2025)"),
        )

        print(f"{input_filename}")
        print(f"  -> {result}")
        print(f"  expected: {expected_output}")

        assert result == expected_output


class TestEdgeCases:
    """Test edge cases and tricky filenames."""

    def test_web_in_title_preserved(self):
        """The word 'Web' in titles should not be stripped."""
        # "Charlotte's Web" should keep "Web"
        result = clean_title("Charlottes.Web.720p")
        print(f'"Charlottes.Web.720p" -> "{result}"')
        assert "Web" in result or "web" in result.lower()

    def test_ellipsis_preserved(self):
        """Ellipsis in titles should be preserved."""
        result = clean_title("What....720p")
        print(f'"What....720p" -> "{result}"')
        assert "..." in result

    def test_part_numbers_preserved(self):
        """Part numbers like (Part 1) should be preserved."""
        result = clean_title("Episode.Title.(Part.1).720p")
        print(f'"Episode.Title.(Part.1).720p" -> "{result}"')
        assert "Part 1" in result or "Part.1" in result
