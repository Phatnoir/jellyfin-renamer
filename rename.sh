#!/bin/bash

# Universal Media Renamer for Jellyfin/Plex
# Renames TV show files and folders to media server compatible format
# Author: Generated for phatnoir
# Usage: ./universal_rename.sh [options] [path]

set -euo pipefail

# Enable case-insensitive globbing for better file matching
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

# Supported video and subtitle extensions
VIDEO_EXTENSIONS="mkv|mp4|avi|m4v|mov|wmv|flv"
SUBTITLE_EXTENSIONS="srt|ass|ssa|vtt|sub"
ALL_EXTENSIONS="$VIDEO_EXTENSIONS|$SUBTITLE_EXTENSIONS"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
Universal Media Renamer for Jellyfin/Plex

Usage: $0 [options] [path]

Options:
  --dry-run           Show what would be renamed without making changes
  --verbose           Show detailed processing information
  --force             Overwrite existing files (use with caution)
  --series "Name"     Specify series name to strip from filenames
  --format FORMAT     Output format (default: "SxxExx - Title")
                      Options: "SxxExx - Title", "SxxExx", "Season X Episode Y - Title"
  --help, -h          Show this help message

Arguments:
  path                Directory to process (default: current directory)

Examples:
  $0 --dry-run --series "Breaking Bad" /path/to/shows
  $0 --verbose --format "SxxExx" .
  $0 --dry-run /mnt/media/tv-shows

Supported formats:
  Video: mkv, mp4, avi, m4v, mov, wmv, flv
  Subtitles: srt, ass, ssa, vtt, sub

The script will:
1. Rename season folders to "Season X" format
2. Extract episode codes (S01E01, 1x01, etc.) and normalize to S01E01
3. Clean episode titles by removing codec info, group tags, etc.
4. Handle special characters safely
5. Skip files already in correct format
EOF
}

# =============================================================================
# TEXT PROCESSING FUNCTIONS
# =============================================================================

normalize_text() {
    local text="$1"
    # Remove leading/trailing whitespace
    text=$(echo "$text" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    # Replace multiple spaces with single space
    # shellcheck disable=SC2001
    text=$(echo "$text" | sed 's/[[:space:]]\+/ /g')
    echo "$text"
}

clean_episode_title() {
    local title="$1"

    print_verbose "Original title: '$title'"

    # Remove common junk patterns
    title=$(echo "$title" | sed -E '
        # Remove series name if provided
        s/^'"$SERIES_NAME"'[[:space:]]*-?[[:space:]]*//i
        # Remove common group tags
        s/\[[^]]*\]//g
        # Remove resolution and codec info
        s/\([^)]*([0-9]{3,4}p|x26[45]|HEVC|AVC|WEB-?DL|BluRay|BDRip|DVDRip|WEBRip)[^)]*\)//gi
        # Remove standalone codec/quality indicators
        s/[[:space:]]+(720p|1080p|2160p|4K|x264|x265|HEVC|H\.264|H\.265)[[:space:]]+/ /gi
        s/[[:space:]]+(WEB-?DL|BluRay|BDRip|DVDRip|WEBRip|HDTV)[[:space:]]+/ /gi
        # Remove file extension artifacts
        s/\.(mkv|mp4|avi|m4v|mov|wmv|flv)$//i
    ')

    # Normalize whitespace
    title=$(normalize_text "$title")

    print_verbose "Cleaned title: '$title'"
    echo "$title"
}

extract_season_episode() {
    local filename="$1"
    local season=""
    local episode=""

    print_verbose "Extracting season/episode from: '$filename'"

    # Pattern 1: S01E01, S1E1, etc.
    if [[ "$filename" =~ [Ss]([0-9]{1,2})[Ee]([0-9]{1,2}) ]]; then
        season=$(printf "%02d" "${BASH_REMATCH[1]}")
        episode=$(printf "%02d" "${BASH_REMATCH[2]}")
        print_verbose "Found S${season}E${episode} pattern"

    # Pattern 2: 1x01, 01x01, etc.
    elif [[ "$filename" =~ ([0-9]{1,2})x([0-9]{1,2}) ]]; then
        season=$(printf "%02d" "${BASH_REMATCH[1]}")
        episode=$(printf "%02d" "${BASH_REMATCH[2]}")
        print_verbose "Found ${season}x${episode} pattern"

    # Pattern 3: Season 1 Episode 1, Season 01 Episode 01, etc.
    elif [[ "$filename" =~ [Ss]eason[[:space:]]*([0-9]{1,2})[[:space:]]*[Ee]pisode[[:space:]]*([0-9]{1,2}) ]]; then
        season=$(printf "%02d" "${BASH_REMATCH[1]}")
        episode=$(printf "%02d" "${BASH_REMATCH[2]}")
        print_verbose "Found Season X Episode Y pattern"

    # Pattern 4: Episode numbers in sequence (risky, requires season context)
    elif [[ "$filename" =~ [Ee]pisode[[:space:]]*([0-9]{1,2}) ]] || [[ "$filename" =~ [Ee]p[[:space:]]*([0-9]{1,2}) ]]; then
        episode=$(printf "%02d" "${BASH_REMATCH[1]}")
        # Try to infer season from parent directory
        local parent_dir=$(basename "$(dirname "$filename")")
        if [[ "$parent_dir" =~ [Ss]eason[[:space:]]*([0-9]{1,2}) ]] || [[ "$parent_dir" =~ [Ss]([0-9]{1,2}) ]]; then
            season=$(printf "%02d" "${BASH_REMATCH[1]}")
        else
            season="01"  # Default to season 1
        fi
        print_verbose "Found Episode pattern, inferred season $season"
    fi

    if [[ -n "$season" && -n "$episode" ]]; then
        echo "S${season}E${episode}"
    else
        echo ""
    fi
}

extract_episode_title() {
    local filename="$1"
    local season_episode="$2"

    print_verbose "Extracting title from: '$filename'"

    # Remove the season/episode part and common separators
    local title="$filename"

    # Remove season/episode patterns
    title=$(echo "$title" | sed -E "s/[Ss][0-9]{1,2}[Ee][0-9]{1,2}[[:space:]]*[-._]*[[:space:]]*//")
    title=$(echo "$title" | sed -E "s/[0-9]{1,2}x[0-9]{1,2}[[:space:]]*[-._]*[[:space:]]*//")
    title=$(echo "$title" | sed -E "s/[Ss]eason[[:space:]]*[0-9]{1,2}[[:space:]]*[Ee]pisode[[:space:]]*[0-9]{1,2}[[:space:]]*[-._]*[[:space:]]*//i")
    title=$(echo "$title" | sed -E "s/[Ee]pisode[[:space:]]*[0-9]{1,2}[[:space:]]*[-._]*[[:space:]]*//i")
    title=$(echo "$title" | sed -E "s/[Ee]p[[:space:]]*[0-9]{1,2}[[:space:]]*[-._]*[[:space:]]*//i")

    # Clean the title
    title=$(clean_episode_title "$title")

    # If title is too short or looks like junk, return empty
    if [[ ${#title} -lt 3 ]] || [[ "$title" =~ ^[0-9.-]+$ ]]; then
        print_verbose "Title too short or looks like junk, discarding"
        echo ""
    else
        echo "$title"
    fi
}

extract_season_number() {
    local folder_name="$1"

    # Extract season number from various patterns
    if [[ "$folder_name" =~ [Ss]eason[[:space:]]*([0-9]{1,2}) ]]; then
        printf "%d" "${BASH_REMATCH[1]}"
    elif [[ "$folder_name" =~ [Ss]([0-9]{1,2}) ]]; then
        printf "%d" "${BASH_REMATCH[1]}"
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

    # Check if file already matches our target formats with proper anchoring
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

    # Extract episode number for fallback
    local episode="${season_episode:4:2}"
    episode=$((10#$episode))  # Remove leading zero

    # Fallback to generic title if empty
    if [[ -z "$title" ]]; then
        title="Episode $episode"
    fi

    case "$OUTPUT_FORMAT" in
        "SxxExx - Title")
            echo "$season_episode - $title.$extension"
            ;;
        "SxxExx")
            echo "$season_episode.$extension"
            ;;
        "Season X Episode Y - Title")
            local season="${season_episode:1:2}"
            season=$((10#$season))  # Remove leading zero
            echo "Season $season Episode $episode - $title.$extension"
            ;;
        *)
            # Fallback to SxxExx - Title
            echo "$season_episode - $title.$extension"
            ;;
    esac
}

# =============================================================================
# MAIN PROCESSING FUNCTIONS
# =============================================================================

rename_season_folders() {
    print_status "$BLUE" "Step 1: Renaming season folders..."

    local folder_count=0

    # Find directories that look like season folders, skip hidden directories
    while IFS= read -r -d '' folder; do
        local folder_name=$(basename "$folder")
        local parent_dir=$(dirname "$folder")

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

        safe_rename "$folder" "$new_folder_path" "folder"
        ((folder_count++))

    done < <(find "$BASE_PATH" -type d -not -path '*/\.*' -regextype posix-extended -regex '.*/.*([Ss]eason|[Ss][0-9]{1,2}).*' -print0)

    if [[ $folder_count -eq 0 ]]; then
        print_status "$YELLOW" "  No season folders found to rename"
    fi
}

rename_episode_files() {
    print_status "$BLUE" "Step 2: Renaming episode files..."

    local file_count=0
    local renamed_count=0

    # Find all media files, skip hidden directories
    while IFS= read -r -d '' file; do
        local file_name=$(basename "$file")
        local file_dir=$(dirname "$file")
        local extension="${file_name##*.}"

        ((file_count++))

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
            ((renamed_count++))
        fi

    done < <(find "$BASE_PATH" -type f -not -path '*/\.*' -regextype posix-extended -regex ".*\.($ALL_EXTENSIONS)$" -print0)

    print_status "$CYAN" "  Processed $file_count files, renamed $renamed_count"
}

show_summary() {
    echo ""
    print_status "$BLUE" "=== Summary ==="

    # Count season folders
    local season_count=$(find "$BASE_PATH" -maxdepth 2 -type d -name "Season *" | wc -l)
    print_status "$GREEN" "Season folders: $season_count"

    # Count formatted episode files
    local formatted_count=0
    case "$OUTPUT_FORMAT" in
        "SxxExx - Title")
            formatted_count=$(find "$BASE_PATH" -type f -regextype posix-extended -regex '.*S[0-9]{2}E[0-9]{2}.*\.('"$ALL_EXTENSIONS"')$' | wc -l)
            ;;
        "SxxExx")
            formatted_count=$(find "$BASE_PATH" -type f -regextype posix-extended -regex '.*S[0-9]{2}E[0-9]{2}\.('"$ALL_EXTENSIONS"')$' | wc -l)
            ;;
        "Season X Episode Y - Title")
            formatted_count=$(find "$BASE_PATH" -type f -regextype posix-extended -regex '.*Season [0-9]+ Episode [0-9]+.*\.('"$ALL_EXTENSIONS"')$' | wc -l)
            ;;
    esac
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

# Convert to absolute path with fallback for systems without GNU realpath
if command -v realpath >/dev/null 2>&1; then
    BASE_PATH=$(realpath "$BASE_PATH")
elif command -v python3 >/dev/null 2>&1; then
    BASE_PATH=$(python3 -c "import os,sys; print(os.path.abspath(sys.argv[1]))" "$BASE_PATH")
else
    # Simple fallback - expand and remove ./
    BASE_PATH=$(cd "$BASE_PATH" && pwd)
fi

# Trap for cleanup on script interruption
trap 'print_status "$RED" "Script interrupted. Exiting..."; exit 130' INT TERM

# Show configuration
print_status "$BLUE" "=== Universal Media Renamer ==="
print_status "$BLUE" "Base path: $BASE_PATH"
print_status "$BLUE" "Output format: $OUTPUT_FORMAT"
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
