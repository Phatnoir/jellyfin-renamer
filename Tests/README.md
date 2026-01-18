# Tests

Unit tests for the `renamer` Python package using pytest.

## Running Tests

```bash
# Run all tests
pytest Tests/

# Verbose output
pytest Tests/ -v

# Run specific test file
pytest Tests/test_parser.py

# Run with coverage
pytest Tests/ --cov=renamer
```

## Test Fixtures

Test data lives in `fixtures/filenames.json` - a corpus of 200+ filename patterns organized by category:

- `episode_patterns` - S01E01, 1x01, anime formats, etc.
- `title_cleaning` - quality tags, release groups, preserving meaningful text
- `series_detection` - extracting series names from folder structures

The fixtures are loaded via `conftest.py` and parametrized into individual test cases.

## Adding Test Cases

Add entries to the appropriate section in `fixtures/filenames.json`. Each test case specifies input and expected output - pytest will automatically pick them up.
