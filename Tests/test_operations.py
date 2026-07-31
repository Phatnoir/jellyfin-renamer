"""
Filesystem integration tests for rename operations.

These tests use pytest's tmp_path fixture to create real files on disk,
verifying that the rename mechanics, companion file handling, output
filename assembly, and end-to-end processing behave correctly — not
just the parser patterns in test_parser.py.

Pattern for each test: arrange (create files) → act (call function) → assert
(check filesystem state and return values).
"""

import pytest
from pathlib import Path

from renamer.operations import (
    OutputFormat,
    RenameOptions,
    RenameSession,
    build_filename,
    process_directory,
    process_video_file,
    rename_companions,
    safe_rename,
)
from renamer.parser import EpisodeInfo


class TestSafeRename:
    """Unit tests for safe_rename() — the core file-move primitive."""

    def test_dry_run_leaves_files_unchanged(self, tmp_path):
        src = tmp_path / "01. HORRIBLE_HISTORIES-S1.mp4"
        src.touch()
        dst = tmp_path / "Horrible Histories - S01E01.mp4"

        result = safe_rename(src, dst, dry_run=True)

        assert result.success is True
        assert src.exists()
        assert not dst.exists()

    def test_actual_rename_moves_file(self, tmp_path):
        src = tmp_path / "01. HORRIBLE_HISTORIES-S1.mp4"
        src.touch()
        dst = tmp_path / "Horrible Histories - S01E01.mp4"

        result = safe_rename(src, dst)

        assert result.success is True
        assert not src.exists()
        assert dst.exists()

    def test_source_not_found_returns_failure(self, tmp_path):
        result = safe_rename(tmp_path / "ghost.mp4", tmp_path / "new.mp4")

        assert result.success is False

    def test_collision_without_force_skips(self, tmp_path):
        src = tmp_path / "episode.mp4"
        src.touch()
        dst = tmp_path / "already_there.mp4"
        dst.touch()

        result = safe_rename(src, dst, force=False)

        assert result.success is False
        assert result.skipped is True
        assert src.exists()
        assert dst.exists()

    def test_collision_with_force_overwrites(self, tmp_path):
        src = tmp_path / "episode.mp4"
        src.write_text("new content")
        dst = tmp_path / "already_there.mp4"
        dst.write_text("old content")

        result = safe_rename(src, dst, force=True)

        assert result.success is True
        assert not src.exists()
        assert dst.read_text() == "new content"

    def test_already_correct_name_skips_with_message(self, tmp_path):
        path = tmp_path / "Horrible Histories - S01E01.mp4"
        path.touch()

        result = safe_rename(path, path)

        assert result.success is True
        assert result.skipped is True
        assert "Already correct" in result.message
        assert path.exists()


class TestRenameCompanions:
    """Unit tests for rename_companions() — subtitle/sidecar file tracking."""

    def test_srt_follows_video_rename(self, tmp_path):
        old_video = tmp_path / "01. Show-S1.mp4"
        new_video = tmp_path / "Show - S01E01.mp4"
        old_video.touch()
        (tmp_path / "01. Show-S1.srt").touch()

        results = rename_companions(old_video, new_video)

        assert len(results) == 1
        assert results[0].success is True
        assert (tmp_path / "Show - S01E01.srt").exists()
        assert not (tmp_path / "01. Show-S1.srt").exists()

    def test_language_code_preserved(self, tmp_path):
        old_video = tmp_path / "01. Show-S1.mp4"
        new_video = tmp_path / "Show - S01E01.mp4"
        old_video.touch()
        (tmp_path / "01. Show-S1.en.srt").touch()

        rename_companions(old_video, new_video)

        assert (tmp_path / "Show - S01E01.en.srt").exists()

    def test_non_companion_extension_ignored(self, tmp_path):
        old_video = tmp_path / "01. Show-S1.mp4"
        new_video = tmp_path / "Show - S01E01.mp4"
        old_video.touch()
        other = tmp_path / "01. Show-S1.exe"
        other.touch()

        results = rename_companions(old_video, new_video)

        assert len(results) == 0
        assert other.exists()

    def test_dry_run_leaves_companions_unchanged(self, tmp_path):
        old_video = tmp_path / "01. Show-S1.mp4"
        new_video = tmp_path / "Show - S01E01.mp4"
        old_video.touch()
        srt = tmp_path / "01. Show-S1.srt"
        srt.touch()

        results = rename_companions(old_video, new_video, dry_run=True)

        assert len(results) == 1
        assert results[0].success is True
        assert srt.exists()
        assert not (tmp_path / "Show - S01E01.srt").exists()

    def test_multiple_companions_all_renamed(self, tmp_path):
        old_video = tmp_path / "01. Show-S1.mp4"
        new_video = tmp_path / "Show - S01E01.mp4"
        old_video.touch()
        (tmp_path / "01. Show-S1.srt").touch()
        (tmp_path / "01. Show-S1.en.srt").touch()
        (tmp_path / "01. Show-S1.nfo").touch()

        results = rename_companions(old_video, new_video)

        assert len(results) == 3
        assert all(r.success for r in results)
        assert (tmp_path / "Show - S01E01.srt").exists()
        assert (tmp_path / "Show - S01E01.en.srt").exists()
        assert (tmp_path / "Show - S01E01.nfo").exists()


class TestBuildFilename:
    """Unit tests for build_filename() — the output format assembler.

    Uses a directory named like a real show so that detect_series_name_no_year()
    returns a predictable value ("Test Show") for formats that strip the year.
    """

    @pytest.fixture
    def show_dir(self, tmp_path):
        d = tmp_path / "Test Show (2020)"
        d.mkdir()
        return d

    def test_show_sxxexx_title_with_title(self, show_dir):
        info = EpisodeInfo(season=1, episode=5)
        result = build_filename(
            info, "My Episode", "mp4",
            "Test Show (2020)", OutputFormat.SHOW_SXXEXX_TITLE, show_dir,
        )
        assert result == "Test Show - S01E05 - My Episode.mp4"

    def test_show_sxxexx_title_without_title(self, show_dir):
        info = EpisodeInfo(season=1, episode=1)
        result = build_filename(
            info, None, "mp4",
            "Test Show (2020)", OutputFormat.SHOW_SXXEXX_TITLE, show_dir,
        )
        assert result == "Test Show - S01E01.mp4"

    def test_show_year_sxxexx_title_includes_year(self, show_dir):
        info = EpisodeInfo(season=2, episode=3)
        result = build_filename(
            info, "My Episode", "mkv",
            "Test Show (2020)", OutputFormat.SHOW_YEAR_SXXEXX_TITLE, show_dir,
        )
        assert result == "Test Show (2020) - S02E03 - My Episode.mkv"

    def test_sxxexx_only_ignores_series_and_title(self, show_dir):
        info = EpisodeInfo(season=3, episode=12)
        result = build_filename(
            info, "Any Title", "mp4",
            "Test Show (2020)", OutputFormat.SXXEXX, show_dir,
        )
        assert result == "S03E12.mp4"

    def test_dual_episode_in_show_sxxexx_format(self, show_dir):
        info = EpisodeInfo(season=1, episode=1, second_episode=2)
        result = build_filename(
            info, None, "mp4",
            "Test Show (2020)", OutputFormat.SHOW_SXXEXX, show_dir,
        )
        assert result == "Test Show - S01E01-E02.mp4"

    def test_extension_preserved(self, show_dir):
        info = EpisodeInfo(season=1, episode=1)
        result = build_filename(
            info, None, "mkv",
            "Test Show (2020)", OutputFormat.SXXEXX, show_dir,
        )
        assert result.endswith(".mkv")


class TestProcessVideoFile:
    """Integration tests for process_video_file() — parser + renamer combined.

    Uses SHOW_SXXEXX format so the output filename is deterministic regardless
    of what the title cleaner extracts from the original name.
    """

    @pytest.fixture
    def session(self, tmp_path):
        show_dir = tmp_path / "Test Show (2009)"
        show_dir.mkdir()
        options = RenameOptions(
            dry_run=True,
            output_format=OutputFormat.SHOW_SXXEXX,
        )
        sess = RenameSession(base_path=show_dir, options=options)
        return sess, show_dir

    def test_leading_number_with_season_pattern_renames_correctly(self, session):
        sess, show_dir = session
        f = show_dir / "01. HORRIBLE_HISTORIES-S1.mp4"
        f.touch()

        result = process_video_file(f, sess)

        assert result is not None
        assert result.success is True
        assert result.new_path.name == "Test Show - S01E01.mp4"

    def test_leading_number_underscore_season_separator(self, session):
        sess, show_dir = session
        f = show_dir / "09. HORRIBLE_HISTORIES_S2.mp4"
        f.touch()

        result = process_video_file(f, sess)

        assert result is not None
        assert result.success is True
        assert result.new_path.name == "Test Show - S02E09.mp4"

    def test_standard_sxxexx_still_works(self, session):
        sess, show_dir = session
        f = show_dir / "Show.S02E05.Title.mkv"
        f.touch()

        result = process_video_file(f, sess)

        assert result is not None
        assert result.success is True
        assert "S02E05" in result.new_path.name

    def test_unparseable_file_returns_failure(self, session):
        sess, show_dir = session
        f = show_dir / "random_movie.mp4"
        f.touch()

        result = process_video_file(f, sess)

        assert result is not None
        assert result.success is False

    def test_specials_folder_sets_season_00(self, tmp_path):
        show_dir = tmp_path / "Test Show (2009)"
        specials_dir = show_dir / "Specials"
        specials_dir.mkdir(parents=True)
        options = RenameOptions(dry_run=True, output_format=OutputFormat.SXXEXX)
        sess = RenameSession(base_path=show_dir, options=options)
        f = specials_dir / "Show.S01E01.Special.mp4"
        f.touch()

        result = process_video_file(f, sess)

        assert result is not None
        assert result.success is True
        assert result.new_path.name == "S00E01.mp4"

    def test_dry_run_does_not_create_file(self, session):
        sess, show_dir = session
        f = show_dir / "01. Show-S1.mp4"
        f.touch()

        process_video_file(f, sess)

        assert f.exists()
        assert not (show_dir / "Test Show - S01E01.mp4").exists()


class TestProcessDirectory:
    """Integration tests for process_directory() — full batch processing."""

    def test_processes_all_video_files(self, tmp_path):
        show_dir = tmp_path / "Test Show (2009)"
        show_dir.mkdir()
        for name in ("01. Show-S1.mp4", "02. Show-S1.mp4", "03. Show-S1.mp4"):
            (show_dir / name).touch()

        options = RenameOptions(dry_run=True, output_format=OutputFormat.SXXEXX)
        results = process_directory(show_dir, options)

        assert len(results) == 3
        assert all(r.success for r in results)

    def test_mixed_parseable_and_unparseable(self, tmp_path):
        show_dir = tmp_path / "Test Show (2009)"
        show_dir.mkdir()
        (show_dir / "01. Show-S1.mp4").touch()
        (show_dir / "random_movie.mp4").touch()

        options = RenameOptions(dry_run=True, output_format=OutputFormat.SXXEXX)
        results = process_directory(show_dir, options)

        successes = [r for r in results if r.success]
        failures = [r for r in results if not r.success]
        assert len(successes) == 1
        assert len(failures) == 1

    def test_dry_run_makes_no_filesystem_changes(self, tmp_path):
        show_dir = tmp_path / "Test Show (2009)"
        show_dir.mkdir()
        (show_dir / "01. Show-S1.mp4").touch()
        (show_dir / "02. Show-S1.mp4").touch()

        options = RenameOptions(dry_run=True, output_format=OutputFormat.SXXEXX)
        process_directory(show_dir, options)

        remaining = list(show_dir.iterdir())
        assert len(remaining) == 2
        assert all(f.name.startswith("0") for f in remaining)

    def test_processes_files_across_season_subdirs(self, tmp_path):
        show_dir = tmp_path / "Test Show (2009)"
        s1 = show_dir / "Season 1"
        s2 = show_dir / "Season 2"
        s1.mkdir(parents=True)
        s2.mkdir()
        (s1 / "01. Show-S1.mp4").touch()
        (s1 / "02. Show-S1.mp4").touch()
        (s2 / "01. Show-S2.mp4").touch()

        options = RenameOptions(dry_run=True, output_format=OutputFormat.SXXEXX)
        results = process_directory(show_dir, options)

        assert len(results) == 3
        assert all(r.success for r in results)
        codes = {r.new_path.name for r in results}
        assert codes == {"S01E01.mp4", "S01E02.mp4", "S02E01.mp4"}
