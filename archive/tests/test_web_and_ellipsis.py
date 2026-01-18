#!/usr/bin/env python3
"""
Test WEB word preservation and ellipsis handling.
Ensures "Web" in titles isn't stripped while technical WEB tags are removed.
Ensures ellipses (...) in titles are preserved.

Usage: python3 test_web_and_ellipsis.py
"""

import subprocess
import sys
from pathlib import Path
import tempfile


def run_test():
    print("=" * 60)
    print("Testing WEB Word & Ellipsis Handling")
    print("=" * 60)
    print()

    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)

        # Find rename.sh
        script_path = Path(__file__).parent.parent / "rename.sh"
        if not script_path.exists():
            print(f"❌ Can't find rename.sh at {script_path}")
            return False

        # === WEB TESTS ===
        web_dir = tmpdir / "WebTest"
        web_dir.mkdir()

        web_cases = [
            # (filename, should_contain, should_not_contain, description)
            ("Show - S01E01 - Tangled Web We Weaved.mkv", "Tangled Web We Weaved", None, "Web in middle of title"),
            ("Show - S01E02 - The Web of Lies.mkv", "The Web of Lies", None, "Web after article"),
            ("Show - S01E03 - Spider Web.mkv", "Spider Web", None, "Web at end of title"),
            ("Show - S01E04 - Webster's Dictionary.mkv", "Webster's Dictionary", None, "Webster - Web prefix"),
            ("Show - S01E05 - Webmaster.mkv", "Webmaster", None, "Webmaster - Web prefix"),
            ("Show - S01E06 - Charlotte's Web.mkv", "Charlotte's Web", None, "Possessive before Web"),
            ("Show - S01E07 - World Wide Web.mkv", "World Wide Web", None, "Multiple words before Web"),
            ("Show - S01E08 - Normal Episode.WEB.x264-GROUP.mkv", "Normal Episode", "WEB", "Strip .WEB.x264"),
            ("Show - S01E09 - Normal Episode.WEB-DL.1080p.mkv", "Normal Episode", "WEB", "Strip .WEB-DL"),
            ("Show - S01E10 - Normal Episode.WEBRip.mkv", "Normal Episode", "WEBRip", "Strip .WEBRip"),
            ("Show - S01E11 - Normal Episode.AMZN.WEB-DL.mkv", "Normal Episode", "AMZN", "Strip .AMZN.WEB-DL"),
            ("Show - S01E12 - Web Design 101.mkv", "Web Design 101", None, "Web at start of title"),
            ("Show.S01E13.Web.Of.Deceit.WEB.x264.mkv", "Web Of Deceit", None, "Dot-separated with Web in title AND tag"),
            ("Show.S01E14.The.Web.WEB-DL.1080p.mkv", "The Web", None, "Dot-separated Web title with WEB-DL tag"),
            ("Show - S01E15 - Webbed Feet.mkv", "Webbed Feet", None, "Webbed - Web prefix"),
        ]

        print("📁 Creating WEB test files...")
        for filename, _, _, desc in web_cases:
            (web_dir / filename).touch()
        print(f"   Created {len(web_cases)} files")
        print()

        # Run rename.sh on WEB tests
        result = subprocess.run(
            ['bash', str(script_path), '--dry-run', '--series', 'Show', str(web_dir)],
            capture_output=True,
            text=True
        )
        web_output = result.stdout + result.stderr

        # === ELLIPSIS TESTS ===
        ellipsis_dir = tmpdir / "EllipsisTest"
        ellipsis_dir.mkdir()

        ellipsis_cases = [
            # (filename, should_contain, description)
            ("Show - S01E01 - It's About George....mkv", "George...", "Trailing ellipsis"),
            ("Show - S01E02 - ... And Girlfriends (2).mkv", "... And Girlfriends", "Leading ellipsis"),
            ("Show - S01E03 - Nobody Knows....mkv", "Knows...", "Trailing ellipsis 2"),
            ("Show - S01E04 - ... And a Nice Chianti.mkv", "... And a Nice", "Leading ellipsis 2"),
            ("Show - S01E05 - Sin... (1).mkv", "Sin...", "Trailing ellipsis with part number"),
            ("Show - S01E06 - ... And Expiation (2).mkv", "... And Expiation", "Leading ellipsis with part number"),
            ("Show - S01E07 - Chances... (1).mkv", "Chances...", "Trailing ellipsis with part number 2"),
            ("Show - S01E08 - ... Are (2).mkv", "... Are", "Leading ellipsis short title"),
        ]

        print("📁 Creating ellipsis test files...")
        for filename, _, desc in ellipsis_cases:
            (ellipsis_dir / filename).touch()
        print(f"   Created {len(ellipsis_cases)} files")
        print()

        # Run rename.sh on ellipsis tests
        result = subprocess.run(
            ['bash', str(script_path), '--dry-run', '--series', 'Show', str(ellipsis_dir)],
            capture_output=True,
            text=True
        )
        ellipsis_output = result.stdout + result.stderr

        # === EVALUATE RESULTS ===
        print("📊 WEB Test Results:")
        print()

        passed = 0
        failed = 0

        for filename, should_contain, should_not_contain, desc in web_cases:
            # Find the output line for this file
            ok = True
            errors = []

            if should_contain and should_contain not in web_output:
                ok = False
                errors.append(f"missing '{should_contain}'")

            if should_not_contain and should_not_contain in web_output:
                # Check it's not in the output filename (could be in input)
                # Look for → lines
                for line in web_output.splitlines():
                    if '→' in line and should_not_contain in line.split('→')[1]:
                        ok = False
                        errors.append(f"still contains '{should_not_contain}'")
                        break

            if ok:
                print(f"   ✅ PASS: {desc}")
                passed += 1
            else:
                print(f"   ❌ FAIL: {desc} ({', '.join(errors)})")
                failed += 1

        print()
        print("📊 Ellipsis Test Results:")
        print()

        for filename, should_contain, desc in ellipsis_cases:
            # Check the output contains the ellipsis
            found = False
            for line in ellipsis_output.splitlines():
                if '→' in line and should_contain in line.split('→')[1]:
                    found = True
                    break

            if found:
                print(f"   ✅ PASS: {desc}")
                passed += 1
            else:
                print(f"   ❌ FAIL: {desc} (missing '{should_contain}')")
                failed += 1

        print()
        print("=" * 60)

        total = len(web_cases) + len(ellipsis_cases)
        if failed == 0:
            print(f"✅ All {passed}/{total} tests passed!")
            print("=" * 60)
            return True
        else:
            print(f"❌ {failed} test(s) failed")
            print(f"   Passed: {passed}/{total}")
            print("=" * 60)
            return False


if __name__ == '__main__':
    success = run_test()
    sys.exit(0 if success else 1)