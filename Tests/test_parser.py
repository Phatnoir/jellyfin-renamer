"""
Tests for episode pattern detection.

These tests verify that the Python parser matches the behavior of the
original Bash implementation for all known filename patterns.
"""

import pytest
from renamer.parser import get_season_episode, EpisodeInfo, normalize_text


class TestStandardSxxExx:
    """Test standard S01E01 format patterns."""

    @pytest.mark.parametrize("filename,expected_season,expected_episode", [
        ("Breaking.Bad.S01E01.Pilot.720p.WEB-DL.x264-GROUP.mkv", 1, 1),
        ("Doctor.Who.2005.S05E04.Time.Of.The.Angels.HDTV.XviD-FoV.avi", 5, 4),
        ("The.Office.S02E15.1080p.BluRay.mkv", 2, 15),
        ("show.s1e5.title.mkv", 1, 5),
        ("Show.S01.E01.Title.mkv", 1, 1),  # space between S and E
        ("Show.S01-E01.Title.mkv", 1, 1),  # dash between S and E
        ("Show.S01_E01.Title.mkv", 1, 1),  # underscore between S and E
        ("Show S10E100.mkv", 10, 100),     # 3-digit episode
    ])
    def test_sxxexx_patterns(self, filename: str, expected_season: int, expected_episode: int):
        result = get_season_episode(filename)
        assert result is not None, f"Failed to parse: {filename}"
        print(f"{filename} -> {result.format_code()}")
        assert result.season == expected_season
        assert result.episode == expected_episode


class TestNxNNFormat:
    """Test 1x01 format patterns."""

    @pytest.mark.parametrize("filename,expected_season,expected_episode", [
        ("Show.1x01.Title.mkv", 1, 1),
        ("Show.01x05.Title.mkv", 1, 5),
        ("Show 2x15 - Episode Title.avi", 2, 15),
        ("show.10x01.finale.mkv", 10, 1),
    ])
    def test_nxnn_patterns(self, filename: str, expected_season: int, expected_episode: int):
        result = get_season_episode(filename)
        assert result is not None, f"Failed to parse: {filename}"
        print(f"{filename} -> {result.format_code()}")
        assert result.season == expected_season
        assert result.episode == expected_episode


class TestSingleSeasonEPattern:
    """Test E01 format for single-season shows."""

    @pytest.mark.parametrize("filename,expected_episode", [
        ("TestShow.E01.mkv", 1),
        ("TestShow.E005.mkv", 5),
        ("TestShow.E010.mkv", 10),
        ("TestShow.E001.mkv", 1),
        ("ShowName.e05.1080p.WEB-DL.mkv", 5),
    ])
    def test_e_patterns(self, filename: str, expected_episode: int):
        result = get_season_episode(filename)
        assert result is not None, f"Failed to parse: {filename}"
        print(f"{filename} -> {result.format_code()}")
        assert result.season == 1  # Always defaults to season 1
        assert result.episode == expected_episode


class TestAnimeFansub:
    """Test anime/fansub naming patterns."""

    @pytest.mark.parametrize("filename,expected_episode", [
        ("[Erai-raws] Cyberpunk - Edgerunners - 01 [1080p][Multiple Subtitle].mkv", 1),
        ("[SubsPlease] Spy x Family - 05 (1080p) [ABC123].mkv", 5),
        ("Show Name - 12 [720p].mkv", 12),
        ("[HorribleSubs] My Hero Academia - 100 [1080p].mkv", 100),
        ("Anime Title - 03 (BD 1080p).mkv", 3),
    ])
    def test_anime_patterns_with_anime_mode(self, filename: str, expected_episode: int):
        result = get_season_episode(filename, anime_mode=True)
        assert result is not None, f"Failed to parse: {filename}"
        print(f"{filename} -> {result.format_code()}")
        assert result.season == 1  # Anime defaults to season 1
        assert result.episode == expected_episode

    def test_anime_pattern_fallback_without_anime_mode(self):
        """Anime patterns should still be detected as fallback even without --anime."""
        filename = "[Erai-raws] Show - 01 [1080p].mkv"
        result = get_season_episode(filename, anime_mode=False)
        assert result is not None, f"Failed to parse: {filename}"
        print(f"{filename} -> {result.format_code()} (no --anime flag)")
        assert result.season == 1
        assert result.episode == 1


class TestNoMatch:
    """Test cases that should NOT match any pattern."""

    @pytest.mark.parametrize("filename", [
        "random_file.mkv",
        "movie.2020.1080p.mkv",
        "some.documentary.mkv",
    ])
    def test_no_match(self, filename: str):
        result = get_season_episode(filename)
        print(f"{filename} -> (no match)")
        assert result is None, f"Should not match but got: {result}"


class TestEpisodeInfoFormatting:
    """Test the EpisodeInfo format_code method."""

    def test_format_standard(self):
        info = EpisodeInfo(season=1, episode=5)
        print(f"Season {info.season}, Episode {info.episode} -> {info.format_code()}")
        assert info.format_code() == "S01E05"

    def test_format_double_digit(self):
        info = EpisodeInfo(season=10, episode=15)
        print(f"Season {info.season}, Episode {info.episode} -> {info.format_code()}")
        assert info.format_code() == "S10E15"

    def test_format_triple_digit_episode(self):
        info = EpisodeInfo(season=1, episode=100)
        print(f"Season {info.season}, Episode {info.episode} -> {info.format_code()}")
        assert info.format_code() == "S01E100"


class TestNormalizeText:
    """Test text normalization for comparison."""

    @pytest.mark.parametrize("input_text,expected", [
        ("Breaking Bad", "breakingbad"),
        ("Doctor Who (2005)", "doctorwho2005"),
        ("The Office", "theoffice"),
        ("3 Body Problem", "3bodyproblem"),
        ("Spy x Family", "spyxfamily"),
    ])
    def test_normalize(self, input_text: str, expected: str):
        result = normalize_text(input_text)
        print(f'"{input_text}" -> "{result}"')
        assert result == expected
