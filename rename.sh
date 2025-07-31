#!/bin/bash

# Universal Media Renamer for Jellyfin/Plex - Enhanced Edition
# Combines robustness of Claude version with flexibility of original
# Author: Enhanced for phatnoir
# Usage: ./universal_rename.sh [options] [path]

# Use moderate error handling - avoid the strict pipefail that caused issues
set -u
shopt -s nocaseglob

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

# Default values
DRY_RUN=false
VERBOSE=false
FORCE=false
SERIES_NAME=""
BASE_PATH="."
OUTPUT_FORMAT="SxxExx - Title"  # Options: "SxxExx - Title", "SxxExx", "Season X Episode Y - Title"
CLEANUP_FLAGS="default"  # New: modular cleanup options

# Supported video and subtitle extensions
VIDEO_EXTENSIONS="mkv|mp4|avi|m4v|mov|wmv|flv|webm|ts|m2ts"
SUBTITLE_EXTENSIONS="srt|ass|ssa|vtt|sub|idx|sup"
ALL_EXTENSIONS="$VIDEO_EXTENSIONS|$SUBTITLE_EXTENSIONS"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_verbose() {
    [[ "$VERBOSE" == true ]] && print_status "$CYAN" "  [VERBOSE] $1"
}

usage() {
    cat << EOF
Universal Media Renamer for Jellyfin/Plex - Enhanced Edition

Usage: $0 [options] [path]

Options:
  --dry-run           Show what would be renamed without making changes
  --verbose           Show detailed processing information
  --force             Overwrite existing files (use with caution)
  --series "Name"     Specify series name to strip from filenames
  --format FORMAT     Output format (default: "SxxExx - Title")
                      Options: "SxxExx - Title", "SxxExx", "Season X Episode Y - Title"
  --cleanup FLAGS     Cleanup options (default: "default")
                      Options: "aggressive", "conservative", "default"
                      Use comma-separated for multiple: "remove-brackets,strip-groups"
  --help, -h          Show this help message

Arguments:
  path                Directory to process (default: current directory)

Examples:
  $0 --dry-run --series "Breaking Bad" /path/to/shows
  $0 --verbose --format "SxxExx" --cleanup "aggressive" .
  $0 --dry-run --cleanup "conservative" /mnt/media/tv-shows

Supported formats:
  Video: mkv, mp4, avi, m4v, mov, wmv, flv, webm, ts, m2ts
  Subtitles: srt, ass, ssa, vtt, sub, idx, sup

Cleanup modes:
  conservative - Minimal cleanup, preserve most text
  default      - Standard cleanup, remove common junk
  aggressive   - Maximum cleanup, strip everything non-essential

The script will:
1. Rename season folders to "Season X" format
2. Extract episode codes (S01E01, 1x01, etc.) and normalize to S01E01
3. Clean episode titles based on cleanup mode
4. Auto-detect when to use clean SxxExx format vs titles
5. Handle special characters and edge cases safely
6. Skip files already in correct format
EOF
}

# =============================================================================
# TEXT PROCESSING FUNCTIONS
# =============================================================================

normalize_text() {
    local text="$1"
    # Remove leading/trailing whitespace
    text=$(echo "$text" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    # Replace multiple spaces/dots/dashes with single space
    text=$(echo "$text" | sed 's/[[:space:]._-]\+/ /g')
    # Trim again after normalization
    text=$(echo "$text" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    echo "$text"
}

clean_episode_title() {
    local title="$1"
    
    print_verbose "Original title: '$title'"
    
    # Remove series name if provided (case insensitive, flexible matching)
    if [[ -n "$SERIES_NAME" ]]; then
        # Handle both "Series Name" and "Series.Name" patterns
        local series_clean=$(echo "$SERIES_NAME" | sed 's/[[:space:]]/[[:space:].]*/g')
        title=$(echo "$title" | sed -E "s/^${series_clean}[[:space:]._-]*//i")
    fi
    
    # Apply cleanup based on flags
    case "$CLEANUP_FLAGS" in
        *aggressive*|*default*)
            # Remove common group tags and brackets
            title=$(echo "$title" | sed 's/\[[^]]*\]//g')  # [brackets]
            title=$(echo "$title" | sed 's/([^)]*)//g')    # (parentheses)
            
            # Remove quality indicators
            title=$(echo "$title" | sed -E 's/[[:space:]._-]*(720p|1080p|2160p|4K|480p)[[:space:]._-]*/ /gi')
            title=$(echo "$title" | sed -E 's/[[:space:]._-]*(x264|x265|HEVC|H\.?264|H\.?265|AVC|h264|H264)[[:space:]._-]*/ /gi')
            
            # Remove source/format indicators
            title=$(echo "$title" | sed -E 's/[[:space:]._-]*(WEB-?DL|WEBDL|WEB|BluRay|BDRip|DVDRip|WEBRip|HDTV|HULU|Netflix|Amazon)[[:space:]._-]*/ /gi')
            
            # Remove audio codec info
            title=$(echo "$title" | sed -E 's/[[:space:]._-]*(AAC|AC3|DTS|EAC3|5\.1|7\.1|2\.0)[[:space:]._-]*/ /gi')
            ;;
    esac
    
    case "$CLEANUP_FLAGS" in
        *aggressive*)
            # Remove release group tags (anything after last dash/dot)
            title=$(echo "$title" | sed -E 's/[[:space:]._-]*-[A-Za-z0-9]+[[:space:]._-]*$//g')
            title=$(echo "$title" | sed -E 's/[[:space:]._-]*\.[A-Za-z0-9]+[[:space:]._-]*$//g')
            
            # Remove "COMPLETE" and similar terms
            title=$(echo "$title" | sed -E 's/[[:space:]._-]*(COMPLETE|PROPER|REPACK|INTERNAL)[[:space:]._-]*/ /gi')
            ;;
    esac
    
    # Always remove file extensions
    title=$(echo "$title" | sed -E "s/\.(${ALL_EXTENSIONS})$//i")
    
    # Normalize the result
    title=$(normalize_text "$title")
    
    print_verbose "Cleaned title: '$title'"
    echo "$title"
}

extract_season_episode() {
    local filename="$1"
    local season=""
    local episode=""
    
    print_verbose "Extracting season/episode from: '$filename'"
    
    # Pattern 1: S01E01, S1E1, etc. (most common)
    if [[ "$filename" =~ [Ss]([0-9]{1,2})[Ee]([0-9]{1,2}) ]]; then
        season="${BASH_REMATCH[1]}"
        episode="${BASH_REMATCH[2]}"
        print_verbose "Found S${season}E${episode} pattern"
    
    # Pattern 2: 1x01, 01x01, etc.
    elif [[ "$filename" =~ ([0-9]{1,2})x([0-9]{1,2}) ]]; then
        season="${BASH_REMATCH[1]}"
        episode="${BASH_REMATCH[2]}"
        print_verbose "Found ${season}x${episode} pattern"
    
    # Pattern 3: Season 1 Episode 1, Season 01 Episode 01, etc.
    elif [[ "$filename" =~ [Ss]eason[[:space:]]*([0-9]{1,2})[[:space:]]*[Ee]pisode[[:space:]]*([0-9]{1,2}) ]]; then
        season="${BASH_REMATCH[1]}"
        episode="${BASH_REMATCH[2]}"
        print_verbose "Found Season X Episode Y pattern"
    
    # Pattern 4: Episode numbers in sequence (requires season context from folder)
    elif [[ "$filename" =~ [Ee]pisode[[:space:]]*([0-9]{1,2}) ]] || [[ "$filename" =~ [Ee]p[[:space:]]*([0-9]{1,2}) ]]; then
        episode="${BASH_REMATCH[1]}"
        # Try to infer season from parent directory
        local parent_dir=$(basename "$(dirname "$filename")")
        if [[ "$parent_dir" =~ [Ss]eason[[:space:]]*([0-9]{1,2}) ]] || [[ "$parent_dir" =~ [Ss]([0-9]{1,2}) ]]; then
            season="${BASH_REMATCH[1]}"
        else
            season="1"  # Default to season 1
        fi
        print_verbose "Found Episode pattern, inferred season $season"
    fi
    
    # Safe zero-padding without printf to avoid octal issues
    if [[ -n "$season" && -n "$episode" ]]; then
        [[ ${#season} -eq 1 ]] && season="0$season"
        [[ ${#episode} -eq 1 ]] && episode="0$episode"
        echo "S${season}E${episode}"
    else
        echo ""
    fi
}

extract_episode_title() {
    local filename="$1"
    local season_episode="$2"
    
    print_verbose "Extracting title from: '$filename'"
    
    local title="$filename"
    
    # Remove season/episode patterns and their common separators
    title=$(echo "$title" | sed -E "s/[Ss][0-9]{1,2}[Ee][0-9]{1,2}[[:space:]._-]*//")
    title=$(echo "$title" | sed -E "s/[0-9]{1,2}x[0-9]{1,2}[[:space:]._-]*//")
    title=$(echo "$title" | sed -E "s/[Ss]eason[[:space:]]*[0-9]{1,2}[[:space:]]*[Ee]pisode[[:space:]]*[0-9]{1,2}[[:space:]._-]*//i")
    title=$(echo "$title" | sed -E "s/[Ee]pisode[[:space:]]*[0-9]{1,2}[[:space:]._-]*//i")
    title=$(echo "$title" | sed -E "s/[Ee]p[[:space:]]*[0-9]{1,2}[[:space:]._-]*//i")
    
    # Clean the title
    title=$(clean_episode_title "$title")
    
    # Determine if we have a meaningful title
    if [[ ${#title} -lt 3 ]] || \
       [[ "$title" =~ ^[0-9.-]+$ ]] || \
       [[ "$title" =~ ^Episode[[:space:]]*[0-9]*$ ]] || \
       [[ "$title" =~ ^(The|A|An)[[:space:]]*$ ]] || \
       [[ "$title" =~ ^[[:space:]]*$ ]]; then
        print_verbose "Title too short, generic, or meaningless - will use clean format"
        echo ""
    else
        echo "$title"
    fi
}

extract_season_number() {
    local folder_name="$1"
    
    # Extract season number from various patterns
    if [[ "$folder_name" =~ [Ss]eason[[:space:]]*([0-9]{1,2}) ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$folder_name" =~ [Ss]([0-9]{1,2}) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

# =============================================================================
# FILE OPERATIONS
# =============================================================================

safe_rename() {
    local old_path="$1"
    local new_path="$2"
    local type="$3"
    
    # Skip if source doesn't exist
    if [[ ! -e "$old_path" ]]; then
        print_status "$YELLOW" "  Warning: Source doesn't exist: $old_path"
        return 1
    fi
    
    # Skip if already correctly named
    if [[ "$old_path" == "$new_path" ]]; then
        print_status "$GREEN" "  ✓ Already correct: $(basename "$new_path")"
        return 0
    fi
    
    # Check if destination already exists
    if [[ -e "$new_path" && "$old_path" != "$new_path" ]]; then
        if [[ "$FORCE" == true ]]; then
            print_status "$YELLOW" "  ! Overwriting existing file (--force enabled)"
        else
            print_status "$RED" "  ✗ Destination exists: $(basename "$new_path") (use --force to overwrite)"
            return 1
        fi
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        print_status "$YELLOW" "  [DRY] $type: $(basename "$old_path") → $(basename "$new_path")"
    else
        if mv "$old_path" "$new_path" 2>/dev/null; then
            print_status "$GREEN" "  ✓ Renamed $type: $(basename "$old_path") → $(basename "$new_path")"
        else
            print_status "$RED" "  ✗ Failed to rename $type: $(basename "$old_path")"
            return 1
        fi
    fi
    return 0
}

is_already_formatted() {
    local filename="$1"
    
    # Check if file already matches target formats
    case "$OUTPUT_FORMAT" in
        "SxxExx - Title")
            [[ "$filename" =~ ^S[0-9]{2}E[0-9]{2}\ -\ .+\.($ALL_EXTENSIONS)$ ]]
            ;;
        "SxxExx")
            [[ "$filename" =~ ^S[0-9]{2}E[0-9]{2}\.($ALL_EXTENSIONS)$ ]]
            ;;
        "Season X Episode Y - Title")
            [[ "$filename" =~ ^Season\ [0-9]+\ Episode\ [0-9]+\ -\ .+\.($ALL_EXTENSIONS)$ ]]
            ;;
        *)
            return 1
            ;;
    esac
}

format_filename() {
    local season_episode="$1"
    local title="$2"
    local extension="$3"
    
    # Smart format selection based on whether we have a meaningful title
    if [[ -z "$title" ]]; then
        # No meaningful title - use clean SxxExx format regardless of setting
        echo "$season_episode.$extension"
    else
        # We have a real title - use the requested format
        case "$OUTPUT_FORMAT" in
            "SxxExx - Title")
                echo "$season_episode - $title.$extension"
                ;;
            "SxxExx")
                echo "$season_episode.$extension"
                ;;
            "Season X Episode Y - Title")
                local season="${season_episode:1:2}"
                local episode="${season_episode:4:2}"
                # Remove leading zeros safely
                season=$((10#$season || 1))
                episode=$((10#$episode || 1))
                echo "Season $season Episode $episode - $title.$extension"
                ;;
            *)
                echo "$season_episode - $title.$extension"
                ;;
        esac
    fi
}

# =============================================================================
# MAIN PROCESSING FUNCTIONS - PORTABLE & ROBUST
# =============================================================================

rename_season_folders() {
    print_status "$BLUE" "Step 1: Renaming season folders..."
    
    local folder_count=0
    local folders_processed=0
    
    # Use simple, portable find instead of complex regex
    while IFS= read -r folder; do
        [[ -z "$folder" ]] && continue
        [[ "$folder" == "$BASE_PATH" ]] && continue
        [[ ! -d "$folder" ]] && continue
        
        local folder_name=$(basename "$folder")
        local parent_dir=$(dirname "$folder")
        
        folders_processed=$((folders_processed + 1))
        print_verbose "Processing folder: $folder_name"
        
        # Skip if already in correct format
        if [[ "$folder_name" =~ ^Season\ [0-9]+$ ]]; then
            print_status "$GREEN" "  ✓ Already correct: $folder_name"
            continue
        fi
        
        # Extract season number
        local season_num=$(extract_season_number "$folder_name")
        if [[ -z "$season_num" ]]; then
            print_verbose "Could not extract season number from: $folder_name"
            continue
        fi
        
        # Create new folder name
        local new_folder_name="Season $season_num"
        local new_folder_path="$parent_dir/$new_folder_name"
        
        if safe_rename "$folder" "$new_folder_path" "folder"; then
            folder_count=$((folder_count + 1))
        fi
        
    done < <(find "$BASE_PATH" -maxdepth 2 -type d 2>/dev/null | grep -E '([Ss]eason|[Ss][0-9]{1,2})' || true)
    
    if [[ $folders_processed -eq 0 ]]; then
        print_status "$YELLOW" "  No season folders found"
    else
        print_status "$CYAN" "  Processed $folders_processed folders, renamed $folder_count"
    fi
}

rename_episode_files() {
    print_status "$BLUE" "Step 2: Renaming episode files..."
    
    local file_count=0
    local renamed_count=0
    
    # Use portable find with explicit file extensions (much more reliable than regex)
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ ! -f "$file" ]] && continue
        
        local file_name=$(basename "$file")
        local file_dir=$(dirname "$file")
        local extension="${file_name##*.}"
        
        file_count=$((file_count + 1))
        
        print_verbose "Processing file: $file_name"
        
        # Skip if already in correct format
        if is_already_formatted "$file_name"; then
            print_status "$GREEN" "  ✓ Already formatted: $file_name"
            continue
        fi
        
        # Extract season and episode
        local season_episode=$(extract_season_episode "$file_name")
        if [[ -z "$season_episode" ]]; then
            print_status "$RED" "  ✗ Could not extract episode info from: $file_name"
            continue
        fi
        
        # Extract episode title
        local episode_title=$(extract_episode_title "$file_name" "$season_episode")
        
        # Format the new filename
        local new_file_name=$(format_filename "$season_episode" "$episode_title" "$extension")
        local new_file_path="$file_dir/$new_file_name"
        
        if safe_rename "$file" "$new_file_path" "file"; then
            renamed_count=$((renamed_count + 1))
        fi
        
    done < <(find "$BASE_PATH" -type f \( -iname '*.mkv' -o -iname '*.mp4' -o -iname '*.avi' -o -iname '*.m4v' -o -iname '*.mov' -o -iname '*.wmv' -o -iname '*.flv' -o -iname '*.webm' -o -iname '*.ts' -o -iname '*.m2ts' -o -iname '*.srt' -o -iname '*.ass' -o -iname '*.ssa' -o -iname '*.vtt' -o -iname '*.sub' -o -iname '*.idx' -o -iname '*.sup' \) 2>/dev/null)
    
    print_status "$CYAN" "  Processed $file_count files, renamed $renamed_count"
}

show_summary() {
    echo ""
    print_status "$BLUE" "=== Summary ==="
    
    # Count season folders
    local season_count=$(find "$BASE_PATH" -maxdepth 2 -type d -name "Season *" 2>/dev/null | wc -l)
    print_status "$GREEN" "Season folders: $season_count"
    
    # Count formatted episode files (simple count of SxxExx pattern)
    local formatted_count=$(find "$BASE_PATH" -type f -name "S[0-9][0-9]E[0-9][0-9]*" 2>/dev/null | wc -l)
    print_status "$GREEN" "Formatted episode files: $formatted_count"
    
    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        print_status "$YELLOW" "This was a dry run. To apply changes, run without --dry-run"
        print_status "$YELLOW" "Review the proposed changes above before proceeding."
    else
        echo ""
        print_status "$GREEN" "Renaming complete!"
        print_status "$BLUE" "Your files should now be compatible with Jellyfin/Plex."
    fi
}

# =============================================================================
# COMMAND LINE PARSING
# =============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --series)
            SERIES_NAME="$2"
            shift 2
            ;;
        --format)
            OUTPUT_FORMAT="$2"
            case "$OUTPUT_FORMAT" in
                "SxxExx - Title"|"SxxExx"|"Season X Episode Y - Title")
                    # Valid format
                    ;;
                *)
                    print_status "$RED" "Error: Invalid format '$OUTPUT_FORMAT'"
                    print_status "$YELLOW" "Valid formats: 'SxxExx - Title', 'SxxExx', 'Season X Episode Y - Title'"
                    exit 1
                    ;;
            esac
            shift 2
            ;;
        --cleanup)
            CLEANUP_FLAGS="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        -*)
            print_status "$RED" "Error: Unknown option $1"
            usage
            exit 1
            ;;
        *)
            BASE_PATH="$1"
            shift
            ;;
    esac
done

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# Validate base path
if [[ ! -d "$BASE_PATH" ]]; then
    print_status "$RED" "Error: Directory '$BASE_PATH' does not exist!"
    exit 1
fi

# Convert to absolute path with multiple fallbacks
if command -v realpath >/dev/null 2>&1; then
    BASE_PATH=$(realpath "$BASE_PATH")
elif command -v python3 >/dev/null 2>&1; then
    BASE_PATH=$(python3 -c "import os,sys; print(os.path.abspath(sys.argv[1]))" "$BASE_PATH")
else
    # Simple fallback
    BASE_PATH=$(cd "$BASE_PATH" && pwd)
fi

# Trap for cleanup on script interruption
trap 'print_status "$RED" "Script interrupted. Exiting..."; exit 130' INT TERM

# Show configuration
print_status "$BLUE" "=== Universal Media Renamer - Enhanced Edition ==="
print_status "$BLUE" "Base path: $BASE_PATH"
print_status "$BLUE" "Output format: $OUTPUT_FORMAT"
print_status "$BLUE" "Cleanup mode: $CLEANUP_FLAGS"
[[ -n "$SERIES_NAME" ]] && print_status "$BLUE" "Series name: $SERIES_NAME"
[[ "$DRY_RUN" == true ]] && print_status "$YELLOW" "DRY RUN MODE - No changes will be made"
[[ "$VERBOSE" == true ]] && print_status "$CYAN" "VERBOSE MODE - Detailed output enabled"
[[ "$FORCE" == true ]] && print_status "$YELLOW" "FORCE MODE - Will overwrite existing files"
echo ""

# Main processing
rename_season_folders
echo ""
rename_episode_files

# Show summary
show_summary

print_status "$PURPLE" "Enhanced Universal Media Renamer completed successfully!"