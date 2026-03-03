#!/usr/bin/env python3
"""
Quick test to verify MP4 deep-clean works before merging to main.
Run this: python3 test_my_branch.py
"""

import subprocess
import sys
from pathlib import Path
import tempfile

def check_requirements():
    """Make sure we have the tools we need"""
    required = ['ffmpeg', 'ffprobe']
    missing = []
    
    for tool in required:
        result = subprocess.run(['which', tool], capture_output=True)
        if result.returncode != 0:
            missing.append(tool)
    
    if missing:
        print(f"❌ Missing required tools: {', '.join(missing)}")
        print("   Install with: sudo apt install ffmpeg  (or brew install ffmpeg on Mac)")
        return False
    return True

def create_dirty_mp4(path: Path):
    """Create an MP4 with metadata that needs cleaning"""
    print(f"📝 Creating test MP4 with dirty metadata...")
    
    result = subprocess.run([
        'ffmpeg', '-f', 'lavfi', '-i', 'color=black:s=320x240:d=1',
        '-metadata', 'title=TestShow.S01E05.1080p.WEB-DL.AAC2.0.x264-TestGroup',
        '-y', str(path)
    ], capture_output=True)
    
    if result.returncode != 0:
        print(f"❌ Failed to create test MP4")
        print(f"   Error: {result.stderr.decode()}")
        return False
    
    print(f"✓ Created: {path.name}")
    return True

def get_mp4_metadata(path: Path) -> str:
    """Extract title from MP4"""
    result = subprocess.run([
        'ffprobe', '-v', 'quiet', '-show_entries', 
        'format_tags=title', '-of', 'default=noprint_wrappers=1:nokey=1',
        str(path)
    ], capture_output=True, text=True)
    
    return result.stdout.strip()

def main():
    print("=" * 60)
    print("Testing MP4 Deep-Clean Feature")
    print("=" * 60)
    print()
    
    # Check requirements
    if not check_requirements():
        return 1
    
    # Create a temp directory for testing
    with tempfile.TemporaryDirectory() as tmpdir:
        test_dir = Path(tmpdir)
        test_file = test_dir / "TestShow.S01E05.mkv.mp4"  # Intentionally weird name
        
        # Step 1: Create dirty MP4
        if not create_dirty_mp4(test_file):
            return 1
        
        # Step 2: Check it has dirty metadata
        print(f"\n📋 Checking metadata before cleaning...")
        metadata_before = get_mp4_metadata(test_file)
        print(f"   Before: '{metadata_before}'")
        
        if not metadata_before:
            print("   ⚠️  Warning: No metadata found (file might not have been created properly)")
        
        has_dirty_metadata = any(tag in metadata_before for tag in ['WEB-DL', 'x264', '1080p', 'AAC'])
        if has_dirty_metadata:
            print(f"   ✓ Has dirty metadata (good for testing)")
        else:
            print(f"   ⚠️  Metadata doesn't look dirty, but continuing...")
        
        # Step 3: Run your script with --deep-clean
        print(f"\n🔧 Running rename.sh --deep-clean...")
        script_path = Path(__file__).parent.parent / "rename.sh"

        if not script_path.exists():
            print(f"❌ Can't find rename.sh at {script_path}")
            print(f"   Make sure rename.sh is in the archive/ directory")
            return 1
        
        result = subprocess.run([
            'bash', str(script_path), '--deep-clean', '--verbose', str(test_dir)
        ], capture_output=True, text=True)
        
        print("   Script stdout:")
        for line in result.stdout.splitlines():
            print(f"     {line}")

        if result.stderr:
            print("   Script stderr (verbose output):")
            for line in result.stderr.splitlines():
                print(f"     {line}")
        
        if result.returncode != 0:
            print(f"   ⚠️  Script exited with code {result.returncode}")
            if result.stderr:
                print(f"   Errors:\n{result.stderr}")
        
        # Step 3.5: FIND THE RENAMED FILE
        # The script renamed our file, so find what it became
        renamed_files = list(test_dir.glob("*.mp4"))
        if len(renamed_files) == 1:
            test_file = renamed_files[0]  # Update to the new filename
            print(f"   File was renamed to: {test_file.name}")
        elif len(renamed_files) == 0:
            print(f"   ❌ ERROR: Original file disappeared!")
            return 1
        else:
            print(f"   ⚠️  Warning: Multiple MP4 files found, using first")
            test_file = renamed_files[0]
        
        # Step 4: Check if metadata was cleaned
        print(f"\n📋 Checking metadata after cleaning...")
        metadata_after = get_mp4_metadata(test_file)
        print(f"   After: '{metadata_after}'")
        
        # Step 5: Verify cleaning worked
        print(f"\n🎯 Results:")
        dirty_tags = ['WEB-DL', 'x264', '1080p', 'AAC', 'TestGroup']
        remaining_dirty = [tag for tag in dirty_tags if tag in metadata_after]
        
        if remaining_dirty:
            print(f"   ❌ FAILED: Still contains: {', '.join(remaining_dirty)}")
            print(f"   The --deep-clean feature might not be working correctly")
            return 1
        else:
            print(f"   ✅ SUCCESS: Metadata cleaned!")
            print(f"   Before: '{metadata_before}'")
            print(f"   After:  '{metadata_after}'")
            print()
            print("=" * 60)
            print("✅ Your branch is ready to merge!")
            print("=" * 60)
            return 0

if __name__ == '__main__':
    sys.exit(main())
