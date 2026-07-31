"""
Tests for episode pattern detection and series name parsing.

All data-driven cases load from fixtures/filenames.json so the corpus is
the single source of truth — adding a case to the JSON automatically adds
a test. Guard tests (precedence, negative matching) that are not data rows
stay inline because they test a specific contract, not a pattern.
"""

import json
from pathlib import Path

import pytest
from renamer.parser import (
    EpisodeInfo,
    detect_series_name,
    get_season_episode,
    normalize_text,
)


# =============================================================================
# CORPUS LOADER
# =============================================================================

def _load_corpus(section: str, subsection: str | None = None) -> list:
    """Load a section (and optional subsection) from filenames.json."""
    corpus_path = Path(__file__).parent / "fixtures" / "filenames.json"
    with corpus_path.open(encoding="utf-8") as f:
        data = json.load(f)
    data = data[section]
    if subsection:
        data = data[subsection]
    return data


# Load all parametrize data at module level so pytest sees it at collection time
_SXXEXX_CASES            = _load_corpus("episode_patterns", "standard_sxxexx")
_NXNN_CASES              = _load_corpus("episode_patterns", "nxnn_format")
_EXX_CASES               = _load_corpus("episode_patterns", "e_pattern_single_season")
_ANIME_CASES             = _load_corpus("episode_patterns", "anime_fansub")
_ANIME_FALLBACK_CASES    = _load_corpus("episode_patterns", "anime_fallback")
_LEADING_NUMBER_CASES    = _load_corpus("episode_patterns", "leading_number_with_season")
_NO_MATCH_CASES          = _load_corpus("episode_patterns", "no_match")

_SD_WITH_YEAR            = _load_corpus("series_detection", "with_year")
_SD_SEASON_SUBFOLDER     = _load_corpus("series_detection", "season_subfolder")
_SD_SPECIALS             = _load_corpus("series_detection", "specials")


# =============================================================================
# EPISODE PATTERN TESTS
# =============================================================================

class TestStandardSxxExx:
    """Test standard S01E01 format patterns."""

    @pytest.mark.parametrize(
        "case",
        _SXXEXX_CASES,
        ids=[c["input"] for c in _SXXEXX_CASES],
    )
    def test_sxxexx_patterns(self, case: dict):
        result = get_season_episode(case["input"])
        assert result is not None, f"Failed to parse: {case['input']}"
        assert result.season == case["season"]
        assert result.episode == case["episode"]


class TestNxNNFormat:
    """Test 1x01 format patterns."""

    @pytest.mark.parametrize(
        "case",
        _NXNN_CASES,
        ids=[c["input"] for c in _NXNN_CASES],
    )
    def test_nxnn_patterns(self, case: dict):
        result = get_season_episode(case["input"])
        assert result is not None, f"Failed to parse: {case['input']}"
        assert result.season == case["season"]
        assert result.episode == case["episode"]


class TestSingleSeasonEPattern:
    """Test E01 format for single-season shows."""

    @pytest.mark.parametrize(
        "case",
        _EXX_CASES,
        ids=[c["input"] for c in _EXX_CASES],
    )
    def test_e_patterns(self, case: dict):
        result = get_season_episode(case["input"])
        assert result is not None, f"Failed to parse: {case['input']}"
        assert result.season == case["season"]
        assert result.episode == case["episode"]


class TestAnimeFansub:
    """Test anime/fansub naming patterns."""

    @pytest.mark.parametrize(
        "case",
        _ANIME_CASES,
        ids=[c["input"] for c in _ANIME_CASES],
    )
    def test_anime_patterns_with_anime_mode(self, case: dict):
        result = get_season_episode(case["input"], anime_mode=True)
        assert result is not None, f"Failed to parse: {case['input']}"
        assert result.season == case["season"]
        assert result.episode == case["episode"]

    @pytest.mark.parametrize(
        "case",
        _ANIME_FALLBACK_CASES,
        ids=[c["input"] for c in _ANIME_FALLBACK_CASES],
    )
    def test_anime_pattern_fallback_without_anime_mode(self, case: dict):
        result = get_season_episode(case["input"], anime_mode=False)
        assert result is not None, f"Failed to parse: {case['input']}"
        assert result.season == case["season"]
        assert result.episode == case["episode"]


class TestLeadingNumberWithSeason:
    """Test "01. Show-S1.mp4" style names (leading episode number + trailing -S# tag).

    Data cases load from corpus. Guard tests stay inline because they pin a
    specific contract (precedence, non-match) rather than a pattern example.
    """

    @pytest.mark.parametrize(
        "case",
        _LEADING_NUMBER_CASES,
        ids=[c["input"] for c in _LEADING_NUMBER_CASES],
    )
    def test_leading_number_with_season(self, case: dict):
        result = get_season_episode(case["input"])
        assert result is not None, f"Failed to parse: {case['input']}"
        assert result.season == case["season"]
        assert result.episode == case["episode"]

    def test_sxxexx_still_wins_over_leading_number(self):
        """A genuine SxxExx code must NOT be hijacked by the leading-number pattern.

        "01. Show-S02E05.mkv" should parse as S02E05 (the embedded code), not
        season=2/episode=1 from the leading "01" + "-S02".
        """
        result = get_season_episode("01. Show-S02E05.mkv")
        assert result is not None
        assert result.season == 2
        assert result.episode == 5

    def test_leading_number_without_season_tag_does_not_match(self):
        """A leading number with no -S# tag must not falsely match."""
        assert get_season_episode("01. Just A Show.mkv") is None


class TestNoMatch:
    """Test cases that should NOT match any pattern."""

    @pytest.mark.parametrize(
        "case",
        _NO_MATCH_CASES,
        ids=[c["input"] for c in _NO_MATCH_CASES],
    )
    def test_no_match(self, case: dict):
        result = get_season_episode(case["input"])
        assert result is None, f"Should not match but got: {result}"


# =============================================================================
# SERIES DETECTION TESTS
# =============================================================================

class TestSeriesDetection:
    """Test detect_series_name() against the series_detection corpus.

    detect_series_name() only reads base_path.name and base_path.parent.name —
    it does not stat the filesystem — so real directories are not needed.
    """

    @pytest.mark.parametrize(
        "case",
        _SD_WITH_YEAR,
        ids=[c["folder"] for c in _SD_WITH_YEAR],
    )
    def test_show_folder_with_year(self, case: dict):
        result = detect_series_name(Path(case["folder"]))
        assert result == case["expected"]

    @pytest.mark.parametrize(
        "case",
        _SD_SEASON_SUBFOLDER,
        ids=[f"{c['parent']}/{c['folder']}" for c in _SD_SEASON_SUBFOLDER],
    )
    def test_season_subfolder(self, case: dict):
        path = Path(case["parent"]) / case["folder"]
        result = detect_series_name(path)
        assert result == case["expected"]

    @pytest.mark.parametrize(
        "case",
        _SD_SPECIALS,
        ids=[f"{c['parent']}/{c['folder']}" for c in _SD_SPECIALS],
    )
    def test_specials_folder(self, case: dict):
        path = Path(case["parent"]) / case["folder"]
        result = detect_series_name(path)
        assert result == case["expected"]


# =============================================================================
# EPISODEINFO FORMATTING
# =============================================================================

class TestEpisodeInfoFormatting:
    """Test the EpisodeInfo format_code method."""

    def test_format_standard(self):
        assert EpisodeInfo(season=1, episode=5).format_code() == "S01E05"

    def test_format_double_digit(self):
        assert EpisodeInfo(season=10, episode=15).format_code() == "S10E15"

    def test_format_triple_digit_episode(self):
        assert EpisodeInfo(season=1, episode=100).format_code() == "S01E100"

    def test_format_dual_episode(self):
        assert EpisodeInfo(season=1, episode=1, second_episode=2).format_code() == "S01E01-E02"

    def test_format_dual_episode_higher_numbers(self):
        assert EpisodeInfo(season=1, episode=25, second_episode=26).format_code() == "S01E25-E26"


# =============================================================================
# TEXT NORMALIZATION
# =============================================================================

class TestNormalizeText:
    """Test text normalization for series name comparison."""

    @pytest.mark.parametrize("input_text,expected", [
        ("Breaking Bad", "breakingbad"),
        ("Doctor Who (2005)", "doctorwho2005"),
        ("The Office", "theoffice"),
        ("3 Body Problem", "3bodyproblem"),
        ("Spy x Family", "spyxfamily"),
    ])
    def test_normalize(self, input_text: str, expected: str):
        assert normalize_text(input_text) == expected
