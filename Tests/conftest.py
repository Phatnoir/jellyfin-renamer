"""
Pytest configuration and shared fixtures.
"""

import json
from pathlib import Path

import pytest


@pytest.fixture
def fixtures_dir() -> Path:
    """Path to the fixtures directory."""
    return Path(__file__).parent / "fixtures"


@pytest.fixture
def test_corpus(fixtures_dir: Path) -> dict:
    """Load the full test corpus from filenames.json."""
    corpus_path = fixtures_dir / "filenames.json"
    with open(corpus_path) as f:
        return json.load(f)


@pytest.fixture
def episode_patterns(test_corpus: dict) -> dict:
    """Just the episode pattern test cases."""
    return test_corpus["episode_patterns"]


@pytest.fixture
def title_cleaning_cases(test_corpus: dict) -> dict:
    """Just the title cleaning test cases."""
    return test_corpus["title_cleaning"]


@pytest.fixture
def series_detection_cases(test_corpus: dict) -> dict:
    """Just the series detection test cases."""
    return test_corpus["series_detection"]
