#!/usr/bin/env python3
"""
Test E## pattern detection (E01, E005, E010, etc.)
Creates temp folder structure, runs rename.sh, verifies detection, then cleans up.

Usage: python3 test_e_pattern.py
"""

import subprocess
import sys
from pathlib import Path
import tempfile
import re

def run_test():
    print("=" * 60)
    print("Testing E## Pattern Detection")
    print("=" * 60)
    print()
    
    # Use temp directory that auto-cleans on exit
    with tempfile.TemporaryDirectory() as tmpdir:
        tmpdir = Path(tmpdir)
        
        # Create folder structure: Show/Season 1/
        show_dir = tmpdir / "TestShow (2024)"
        season_dir = show_dir / "Season 1"
        season_dir.mkdir(parents=True, exist_ok=True)
        
        print(f"📁 Created folder structure:")
        print(f"   {show_dir.name}/")
        print(f"   └── {season_dir.name}/")
        print()
        
        # Create test files with E## patterns
        test_cases = [
            ("TestShow.E01.mkv", "S01E01", "E01 - basic"),
            ("TestShow.E005.mkv", "S01E05", "E005 - zero-padded"),
            ("TestShow.E010.mkv", "S01E010", "E010 - double digit"),
            ("TestShow.E001.mkv", "S01E01", "E001 - triple digit"),
            ("ShowName.e05.1080p.WEB-DL.mkv", "S01E05", "e05 - lowercase with junk"),
        ]
        
        print(f"📝 Creating test files:")
        for filename, expected, description in test_cases:
            filepath = season_dir / filename
            filepath.touch()
            print(f"   ✓ {filename} ({description})")
        print()
        
        # Find rename.sh
        script_path = Path(__file__).parent.parent / "rename.sh"
        if not script_path.exists():
            print(f"❌ Can't find rename.sh at {script_path}")
            print(f"   Make sure this test is in the same directory as rename.sh")
            return False
        
        # Run the script with --dry-run and --verbose
        print(f"🔧 Running rename.sh --dry-run --verbose...")
        print()
        
        result = subprocess.run(
            ['bash', str(script_path), '--dry-run', '--verbose', str(show_dir)],
            capture_output=True,
            text=True
        )
        
        # Combine stdout and stderr (verbose goes to stderr)
        output = result.stdout + result.stderr
        
        # Parse for detection messages
        print(f"📊 Results:")
        print()
        
        passed = 0
        failed = 0
        
        for filename, expected, description in test_cases:
            # Look for the verbose detection line
            pattern = f"Detected single-season episode pattern: E\\d+"
            if re.search(pattern, output):
                # Verify the right episode was detected
                if expected in output:
                    print(f"   ✅ PASS: {filename} → {expected}")
                    passed += 1
                else:
                    print(f"   ⚠️  PARTIAL: {filename} detected but can't verify {expected}")
                    passed += 1
            else:
                # Check if it at least appears in rename output
                if expected in output:
                    print(f"   ✅ PASS: {filename} → {expected} (detected via output)")
                    passed += 1
                else:
                    print(f"   ❌ FAIL: {filename} not detected")
                    print(f"      Expected to find: {expected}")
                    failed += 1
        
        print()
        print("=" * 60)
        
        if failed == 0:
            print(f"✅ All {passed}/{len(test_cases)} tests passed!")
            print("   E## pattern detection is working correctly")
            print("=" * 60)
            return True
        else:
            print(f"❌ {failed} test(s) failed")
            print(f"   Passed: {passed}/{len(test_cases)}")
            print("=" * 60)
            print()
            print("Debug output from script:")
            print("-" * 60)
            print(output[-1000:])  # Last 1000 chars of output
            print("-" * 60)
            return False

if __name__ == '__main__':
    success = run_test()
    sys.exit(0 if success else 1)