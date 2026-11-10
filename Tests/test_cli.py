"""CLI exit-code tests: per-file failures must fail the run.

`main()` used to print per-file errors yet always return 0 alongside a
"completed successfully!" message, which breaks scripting/automation.
"""

from renamer.cli import main


def _make_show(tmp_path, *filenames):
    show = tmp_path / "Show"
    show.mkdir()
    for name in filenames:
        (show / name).touch()
    return show


def test_main_returns_nonzero_when_files_fail(tmp_path, capsys):
    show = _make_show(tmp_path, "random-video.mp4")
    code = main([str(show)])
    assert code == 1
    out = capsys.readouterr().out
    assert "Failed files: 1" in out
    assert "Completed with errors." in out
    assert "completed successfully" not in out
    # Nothing was renamed or created.
    assert sorted(p.name for p in show.iterdir()) == ["random-video.mp4"]


def test_main_returns_zero_when_all_files_process(tmp_path, capsys):
    show = _make_show(tmp_path, "Show - S01E01.mp4")
    code = main([str(show)])
    assert code == 0
    out = capsys.readouterr().out
    assert "completed successfully" in out
