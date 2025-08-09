#!/bin/bash

# Universal Media Renamer for Jellyfin/Plex - Fixed Edition
# Fixed title extraction and year handling for complex filenames
# Usage: ./rename.sh [options] [path]

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
OUTPUT_FORMAT="Show - SxxExx - Title"

# Supported video extensions
VIDEO_EXTENSIONS="mkv|mp4|avi|m4v|mov|wmv|flv|webm|ts|m2ts"

# Color codes
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
PURPLE="\033[0;35m"
NC="\033[0m"

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
Universal Media Renamer for Jellyfin/Plex - Fixed Edition

Usage: $0 [options] [path]

Options:
  --dry-run           Show what would be renamed without making changes
  --verbose           Show detailed processing information
  --force             Overwrite existing files (use with caution)
  --series "Name"     Specify series name (auto-detected if not provided)
  --format FORMAT     Output format (default: "Show - SxxExx - Title")
                      Options: 
                        "Show (Year) - SxxExx - Title" (e.g., "Breaking Bad (2008) - S01E01 - Pilot.mkv")
                        "Show (Year) - SxxExx" (e.g., "Breaking Bad (2008) - S01E01.mkv")
                        "Show - SxxExx - Title" (e.g., "Breaking Bad - S01E01 - Pilot.mkv")
                        "Show - SxxExx" (e.g., "Breaking Bad - S01E01.mkv")
                        "SxxExx - Title" (e.g., "S01E01 - Pilot.mkv")
                        "SxxExx" (e.g., "S01E01.mkv")
  --help, -h          Show this help message

Arguments:
  path                Directory to process (default: current directory)

Examples:
  $0 --dry-run .
  $0 --series "Doctor Who (2005)" --dry-run /path/to/shows
  $0 --format "Show (Year) - SxxExx - Title" --dry-run .

The script will:
1. Auto-detect series name from folder or filenames
2. Extract episode codes and normalize to S01E01 format
3. Clean episode titles intelligently
4. Use appropriate format based on available information
5. Handle special characters and edge cases safely
EOF
}

# =============================================================================
# CORE FUNCTIONS - NO VERBOSE OUTPUT IN THESE
# =============================================================================

detect_series_name() {
    local base_path="$1"
    local parent_name
    local clean_name
    
    parent_name=$(basename "$base_path")
    
    # Check if we're in a Season/season folder
    if [[ "$parent_name" =~ ^[Ss]eason[[:space:]]*[0-9]+$ ]] || [[ "$parent_name" =~ ^[Ss][0-9]+$ ]]; then
        # We're in a season folder, go up one more level for the series name
        local grandparent_path=$(dirname "$base_path")
        parent_name=$(basename "$grandparent_path")
    fi
    
    # Also check for "Specials" folder
    if [[ "$parent_name" =~ ^[Ss]pecials?$ ]]; then
        # We're in a specials folder, go up one more level for the series name
        local grandparent_path=$(dirname "$base_path")
        parent_name=$(basename "$grandparent_path")
    fi
    
    clean_name="$parent_name"
    
    # Remove season indicators but keep year
    clean_name=$(echo "$clean_name" | sed 's/ *- *[Ss]eason.*$//')
    clean_name=$(echo "$clean_name" | sed 's/ *[Ss][0-9][0-9]*.*$//')
    
    # Clean up dots, underscores, and normalize spacing
    clean_name=$(echo "$clean_name" | sed 's/[._]/ /g')
    clean_name=$(echo "$clean_name" | sed 's/  */ /g')
    clean_name=$(echo "$clean_name" | sed 's/^ *//; s/ *$//')
    
    echo "$clean_name"
}

detect_series_name_no_year() {
    local base_path="$1"
    local clean_name
    
    clean_name=$(detect_series_name "$base_path")
    
    # Remove year patterns
    clean_name=$(echo "$clean_name" | sed 's/ *(2[0-9][0-9][0-9]).*$//')
    clean_name=$(echo "$clean_name" | sed 's/ *(19[0-9][0-9]).*$//')
    clean_name=$(echo "$clean_name" | sed 's/ *\[[0-9][0-9][0-9][0-9]\].*$//')
    clean_name=$(echo "$clean_name" | sed 's/^ *//; s/ *$//')
    
    echo "$clean_name"
}

get_season_episode() {
    local filename="$1"
    local season=""
    local episode=""
    
    # Pattern 1: S01E01, S1E1, etc.
    if [[ "$filename" =~ [Ss]([0-9]{1,2})[Ee]([0-9]{1,2}) ]]; then
        season="${BASH_REMATCH[1]}"
        episode="${BASH_REMATCH[2]}"
    
    # Pattern 2: 1x01, 01x01, etc.
    elif [[ "$filename" =~ ([0-9]{1,2})x([0-9]{1,2}) ]]; then
        season="${BASH_REMATCH[1]}"
        episode="${BASH_REMATCH[2]}"
    fi
    
    # Zero-pad season and episode
    if [[ -n "$season" && -n "$episode" ]]; then
        [[ ${#season} -eq 1 ]] && season="0$season"
        [[ ${#episode} -eq 1 ]] && episode="0$episode"
        echo "S${season}E${episode}"
    else
        echo ""
    fi
}

clean_title() {
    local title="$1"
    local series_name="$2"
    
    # Remove series name patterns if provided
    if [[ -n "$series_name" ]]; then
        # Get series name without year for cleaning
        local series_no_year
        series_no_year=$(echo "$series_name" | sed 's/ *(19[0-9][0-9])//g; s/ *(2[0-9][0-9][0-9])//g')
        
        # Convert series name variations to match common filename patterns
        local series_dot="${series_no_year// /.}"
        local series_dash="${series_no_year// /-}"
        local series_under="${series_no_year// /_}"
        
        # Remove series patterns (case insensitive)
        title=$(echo "$title" | sed "s/^${series_dot}[._-]*//gi" 2>/dev/null || echo "$title")
        title=$(echo "$title" | sed "s/^${series_dash}[._-]*//gi" 2>/dev/null || echo "$title")
        title=$(echo "$title" | sed "s/^${series_under}[._-]*//gi" 2>/dev/null || echo "$title")
        title=$(echo "$title" | sed "s/^${series_no_year}[._-]*//gi" 2>/dev/null || echo "$title")
        
        # Also remove series name with year patterns (like "Doctor Who 2005")
        title=$(echo "$title" | sed "s/^${series_no_year} 2[0-9][0-9][0-9][._-]*//gi" 2>/dev/null || echo "$title")
        title=$(echo "$title" | sed "s/^${series_no_year} 19[0-9][0-9][._-]*//gi" 2>/dev/null || echo "$title")
    fi
    
    # FIXED: Better technical tag removal with word boundaries and separators
    # Remove everything after common quality/codec indicators (with proper separators)
    title=$(echo "$title" | sed -E 's/[._ -]+(720p|1080p|2160p|4K|480p|576p)([._ -].*)?$//i')
    title=$(echo "$title" | sed -E 's/[._ -]+(x264|x265|HEVC|H\.?264|H\.?265)([._ -].*)?$//i')
    title=$(echo "$title" | sed -E 's/[._ -]+(WEB(-DL)?|BluRay|BDRip|DVDRip|HDTV|PDTV)([._ -].*)?$//i')
    title=$(echo "$title" | sed -E 's/[._ -]+(AMZN|NFLX|HULU|DSNP|HBO|MAX)([._ -].*)?$//i')
    title=$(echo "$title" | sed -E 's/[._ -]+(AAC|AC3|DTS|DDP([0-9](\.[0-9])?)?)([._ -].*)?$//i')
    
    # Restore missing ws cleanup
    title=$(echo "$title" | sed 's/[._-]*ws[._-]*/ /gi')
    
    # Remove everything in parentheses EXCEPT if it's the entire title
    # This preserves titles like "(Part 1)" when that's all we have
    if [[ ! "$title" =~ ^\([^\)]+\)$ ]]; then
        title=$(echo "$title" | sed 's/([^)]*)//g')
    fi
    title=$(echo "$title" | sed 's/\[[^]]*\]//g')
    
    # FIXED: Better release group removal (case-insensitive, handles lowercase)
    title=$(echo "$title" | sed -E 's/-[A-Za-z0-9]+$//')
    
    # Remove technical abbreviations that survived
    title=$(echo "$title" | sed -E 's/(^|[._ -])(DL|DDP?)([._ -]|$)/\1\3/Ig')
    
    # Remove common tags as whole words
    title=$(echo "$title" | sed 's/\b\(FIXED\|REPACK\|PROPER\|INTERNAL\|EXTENDED\|UNCUT\|DIRECTORS\|CUT\)\b//gi')
    
    # Remove file extensions
    title=$(echo "$title" | sed 's/\.mkv$//i')
    title=$(echo "$title" | sed 's/\.mp4$//i')
    title=$(echo "$title" | sed 's/\.avi$//i')
    
    # Normalize spacing and punctuation
    title=$(echo "$title" | sed 's/[._]/ /g')
    title=$(echo "$title" | sed 's/  */ /g')
    title=$(echo "$title" | sed 's/^ *//; s/ *$//')
    
    # Remove trailing numbers that might be leftover from cleaning
    title=$(echo "$title" | sed 's/ [0-9][0-9]*$//g')
    title=$(echo "$title" | sed 's/^ *//; s/ *$//')
    
    echo "$title"
}

get_episode_title() {
    local filename="$1"
    local season_episode="$2"
    local series_name="$3"
    local title
    
    # Start with just the filename without extension
    title="${filename%.*}"
    
    # Remove season/episode patterns first
    title=$(echo "$title" | sed "s/[Ss][0-9][0-9]*[Ee][0-9][0-9]*[._-]*//")
    title=$(echo "$title" | sed "s/[0-9][0-9]*x[0-9][0-9]*[._-]*//")
    
    # Remove series name and year combo (like "Doctor Who 2006")
    if [[ -n "$series_name" ]]; then
        local series_no_year
        series_no_year=$(echo "$series_name" | sed 's/ *(19[0-9][0-9])//g; s/ *(2[0-9][0-9][0-9])//g')
        # Remove series with any year
        title=$(echo "$title" | sed "s/^${series_no_year} [12][0-9][0-9][0-9] *//i" 2>/dev/null || echo "$title")
        # Remove just series name
        title=$(echo "$title" | sed "s/^${series_no_year} *//i" 2>/dev/null || echo "$title")
    fi
    
    # SIMPLIFIED: Find where technical metadata starts and cut there
    # Technical metadata in these files starts with quality indicators
    local clean_title=""
    
    # Look for the first quality indicator and cut everything before it
    if [[ "$title" =~ ^(.+)\.(720p|1080p|2160p|4K|480p|576p) ]]; then
        clean_title="${BASH_REMATCH[1]}"
        print_verbose "Found quality boundary at '${BASH_REMATCH[2]}', title: '$clean_title'"
    # Fallback to other common first indicators if no quality found
    elif [[ "$title" =~ ^(.+)\.(WEB-DL|BluRay|BDRip|HDTV) ]]; then
        clean_title="${BASH_REMATCH[1]}"
        print_verbose "Found source boundary at '${BASH_REMATCH[2]}', title: '$clean_title'"
    elif [[ "$title" =~ ^(.+)\.(AMZN|NFLX|HULU) ]]; then
        clean_title="${BASH_REMATCH[1]}"
        print_verbose "Found platform boundary at '${BASH_REMATCH[2]}', title: '$clean_title'"
    fi
    
    # If we found a boundary, use that; otherwise keep the whole thing
    if [[ -n "$clean_title" && ${#clean_title} -gt 2 ]]; then
        title="$clean_title"
        print_verbose "Using boundary-detected title: '$title'"
    else
        print_verbose "No technical boundary found, using full title: '$title'"
    fi
    
    # RESTORED: Enhanced parentheses-aware title parsing
    # Handle parentheses intelligently before other cleaning
    if [[ "$title" =~ ^([^\(]+)\( ]]; then
        # There is text before parentheses - use that
        title="${BASH_REMATCH[1]}"
    elif [[ "$title" =~ ^\(([^\)]+)\)$ ]]; then
        # The whole thing is in parentheses - check if it is technical
        local paren_content="${BASH_REMATCH[1]}"
        case "$paren_content" in
            ws|pdtv|xvid|repack|proper|internal|web|h264|x264|x265|hevc|hdtv|bdrip|brip|gothic|fov|rarbg)
                # Technical content, ignore it
                ;;
            *)
                # Looks like a real title
                title="$paren_content"
                ;;
        esac
    fi
    
    # Remove year at the beginning of the title
    title=$(echo "$title" | sed "s/^[12][0-9][0-9][0-9][[:space:]]*//") 
    
    # Clean the title (removes metadata, etc.)
    title=$(clean_title "$title" "$series_name")
    
    # Remove year AGAIN after cleaning, in case it survived
    title=$(echo "$title" | sed "s/^[12][0-9][0-9][0-9][[:space:]]*//") 
    
    # Final cleanup of common tags that might have survived
    title=$(echo "$title" | sed "s/\b\(FIXED\|REPACK\|PROPER\|INTERNAL\)\b//gi")
    title=$(echo "$title" | sed "s/  */ /g")
    title=$(echo "$title" | sed "s/^ *//; s/ *$//")
	
	# Remove leading/trailing dashes and spaces that might cause double dashes
	title=$(echo "$title" | sed 's/^[- ]*//; s/[- ]*$//')
    
    # EXPANDED: Check if we have a meaningful title (includes more release groups)
    if [[ ${#title} -lt 3 ]] || \
       [[ "$title" =~ ^[0-9.-]+$ ]] || \
       [[ "$title" =~ ^(WEB|H264|X264|X265|HEVC|HDTV|AMZN|DL|DDP|AAC|AC3|GOTHIC|RARBG|FOV|PROPER|REPACK|INTERNAL|VIETNAM)$ ]]; then
        echo ""
    else
        echo "$title"
    fi
}

build_filename() {
    local season_episode="$1"
    local title="$2"
    local extension="$3"
    local series_name="$4"
    
    case "$OUTPUT_FORMAT" in
        "Show (Year) - SxxExx - Title")
            if [[ -n "$title" && -n "$series_name" ]]; then
                echo "$series_name - $season_episode - $title.$extension"
            elif [[ -n "$series_name" ]]; then
                echo "$series_name - $season_episode.$extension"
            elif [[ -n "$title" ]]; then
                echo "$season_episode - $title.$extension"
            else
                echo "$season_episode.$extension"
            fi
            ;;
        "Show (Year) - SxxExx")
            if [[ -n "$series_name" ]]; then
                echo "$series_name - $season_episode.$extension"
            else
                echo "$season_episode.$extension"
            fi
            ;;
        "Show - SxxExx - Title")
            local clean_series_name
            if [[ -n "$series_name" ]]; then
                clean_series_name=$(detect_series_name_no_year "$BASE_PATH")
            fi
            if [[ -n "$title" && -n "$clean_series_name" ]]; then
                echo "$clean_series_name - $season_episode - $title.$extension"
            elif [[ -n "$clean_series_name" ]]; then
                echo "$clean_series_name - $season_episode.$extension"
            elif [[ -n "$title" ]]; then
                echo "$season_episode - $title.$extension"
            else
                echo "$season_episode.$extension"
            fi
            ;;
        "Show - SxxExx")
            local clean_series_name
            if [[ -n "$series_name" ]]; then
                clean_series_name=$(detect_series_name_no_year "$BASE_PATH")
                echo "$clean_series_name - $season_episode.$extension"
            else
                echo "$season_episode.$extension"
            fi
            ;;
        "SxxExx - Title")
            if [[ -n "$title" ]]; then
                echo "$season_episode - $title.$extension"
            else
                echo "$season_episode.$extension"
            fi
            ;;
        "SxxExx")
            echo "$season_episode.$extension"
            ;;
        *)
            # Default fallback (Show (Year) - SxxExx - Title)
            if [[ -n "$title" && -n "$series_name" ]]; then
                echo "$series_name - $season_episode - $title.$extension"
            elif [[ -n "$series_name" ]]; then
                echo "$series_name - $season_episode.$extension"
            else
                echo "$season_episode.$extension"
            fi
            ;;
    esac
}

# =============================================================================
# FILE OPERATIONS
# =============================================================================

safe_rename() {
    local old_path="$1"
    local new_path="$2"
    local type="$3"
    
    # Skip if source does not exist
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

# =============================================================================
# MAIN PROCESSING
# =============================================================================

rename_episode_files() {
    print_status "$BLUE" "Processing episode files..."
    
    local file_count=0
    local renamed_count=0
    local detected_series="$SERIES_NAME"
    
    # Auto-detect series name if not provided
    if [[ -z "$detected_series" ]]; then
        detected_series=$(detect_series_name "$BASE_PATH")
        print_status "$CYAN" "Auto-detected series: '$detected_series'"
        print_verbose "Original folder name: '$(basename "$BASE_PATH")'"
        print_verbose "Auto-detected series name: '$detected_series'"
    fi
    
    # Process video files
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ ! -f "$file" ]] && continue
        
        local file_name=$(basename "$file")
        local file_dir=$(dirname "$file")
        local extension="${file_name##*.}"
        
        file_count=$((file_count + 1))
        
        print_verbose "Processing file: $file_name"
        
        # Extract season and episode
        local season_episode
        season_episode=$(get_season_episode "$file_name")
        if [[ -z "$season_episode" ]]; then
            print_status "$RED" "  ✗ Could not extract episode info from: $file_name"
            continue
        fi
        print_verbose "Extracted season/episode: $season_episode"
        
        # Extract episode title
        local episode_title
        episode_title=$(get_episode_title "$file_name" "$season_episode" "$detected_series")
        print_verbose "Extracted episode title: '$episode_title'"
        
        # Format the new filename
        local new_file_name
        new_file_name=$(build_filename "$season_episode" "$episode_title" "$extension" "$detected_series")
        local new_file_path="$file_dir/$new_file_name"
        print_verbose "Formatted filename: '$new_file_name'"
        
        # Skip if already in correct format
        if [[ "$file_name" == "$new_file_name" ]]; then
            print_status "$GREEN" "  ✓ Already formatted: $file_name"
            continue
        fi
        
        if safe_rename "$file" "$new_file_path" "file"; then
            renamed_count=$((renamed_count + 1))
        fi
        
    done < <(find "$BASE_PATH" -type f \( -iname '*.mkv' -o -iname '*.mp4' -o -iname '*.avi' -o -iname '*.m4v' -o -iname '*.mov' -o -iname '*.wmv' -o -iname '*.flv' -o -iname '*.webm' -o -iname '*.ts' -o -iname '*.m2ts' \) 2>/dev/null)
    
    print_status "$CYAN" "  Processed $file_count files, renamed $renamed_count"
}

rename_subtitle_files() {
    print_status "$BLUE" "Processing subtitle files..."
    
    local sub_count=0
    local renamed_count=0
    local detected_series="$SERIES_NAME"
    
    # Auto-detect series name if not provided
    if [[ -z "$detected_series" ]]; then
        detected_series=$(detect_series_name "$BASE_PATH")
        print_verbose "Using series name: '$detected_series'"
    fi
    
    # Process subtitle files
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ ! -f "$file" ]] && continue
        
        local file_name=$(basename "$file")
        local file_dir=$(dirname "$file")
        local extension="${file_name##*.}"
        
        sub_count=$((sub_count + 1))
        
        print_verbose "Processing subtitle: $file_name"
        
        # Extract season and episode
        local season_episode
        season_episode=$(get_season_episode "$file_name")
        if [[ -z "$season_episode" ]]; then
            print_status "$RED" "  ✗ Could not extract episode info from: $file_name"
            continue
        fi
        print_verbose "Extracted season/episode: $season_episode"
        
        # Check for language code in filename (e.g., .en.srt, .eng.srt)
        local lang_code=""
        local base_name="${file_name%.*}"  # Remove extension
        
        # Check if there's a language code before the extension
        if [[ "$base_name" =~ \.([a-z]{2,3})$ ]]; then
            lang_code="${BASH_REMATCH[1]}"
            print_verbose "Detected language code: $lang_code"
        fi
        
        # Extract episode title
        local episode_title
        episode_title=$(get_episode_title "$file_name" "$season_episode" "$detected_series")
        print_verbose "Extracted episode title: '$episode_title'"
        
        # Build new filename
        local new_file_name
        local base_new_name
        base_new_name=$(build_filename "$season_episode" "$episode_title" "" "$detected_series")
        base_new_name="${base_new_name%.*}"  # Remove empty extension added by build_filename
        
        # Add language code if present
        if [[ -n "$lang_code" ]]; then
            new_file_name="${base_new_name}.${lang_code}.${extension}"
        else
            new_file_name="${base_new_name}.${extension}"
        fi
        
        local new_file_path="$file_dir/$new_file_name"
        print_verbose "Formatted subtitle filename: '$new_file_name'"
        
        # Skip if already in correct format
        if [[ "$file_name" == "$new_file_name" ]]; then
            print_status "$GREEN" "  ✓ Already formatted: $file_name"
            continue
        fi
        
        if safe_rename "$file" "$new_file_path" "subtitle"; then
            renamed_count=$((renamed_count + 1))
        fi
        
    done < <(find "$BASE_PATH" -type f \( -iname '*.srt' -o -iname '*.sub' -o -iname '*.ass' -o -iname '*.ssa' -o -iname '*.vtt' \) 2>/dev/null)
    
    if [[ $sub_count -gt 0 ]]; then
        print_status "$CYAN" "  Processed $sub_count subtitle files, renamed $renamed_count"
    fi
}

show_summary() {
    echo ""
    print_status "$BLUE" "=== Summary ==="
    
    local file_count
    local sub_count
    file_count=$(find "$BASE_PATH" -type f \( -iname '*.mkv' -o -iname '*.mp4' -o -iname '*.avi' -o -iname '*.m4v' -o -iname '*.mov' -o -iname '*.wmv' -o -iname '*.flv' -o -iname '*.webm' -o -iname '*.ts' -o -iname '*.m2ts' \) 2>/dev/null | wc -l)
    sub_count=$(find "$BASE_PATH" -type f \( -iname '*.srt' -o -iname '*.sub' -o -iname '*.ass' -o -iname '*.ssa' -o -iname '*.vtt' \) 2>/dev/null | wc -l)
    
    print_status "$GREEN" "Total episode files: $file_count"
    [[ $sub_count -gt 0 ]] && print_status "$GREEN" "Total subtitle files: $sub_count"
    
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
                "Show (Year) - SxxExx - Title"|"Show (Year) - SxxExx"|"Show - SxxExx - Title"|"Show - SxxExx"|"SxxExx - Title"|"SxxExx")
                    # Valid format
                    ;;
                *)
                    print_status "$RED" "Error: Invalid format \"$OUTPUT_FORMAT\""
					print_status "$YELLOW" "Valid formats: \"Show (Year) - SxxExx - Title\", \"Show - SxxExx\", etc."
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
    print_status "$RED" "Error: Directory \"$BASE_PATH\" does not exist!"
    exit 1
fi

# Convert to absolute path
if command -v realpath >/dev/null 2>&1; then
    BASE_PATH=$(realpath "$BASE_PATH")
else
    BASE_PATH=$(cd "$BASE_PATH" && pwd)
fi

# Show configuration
print_status "$BLUE" "=== Universal Media Renamer - Fixed Edition ==="
print_status "$BLUE" "Base path: $BASE_PATH"
print_status "$BLUE" "Output format: $OUTPUT_FORMAT"
[[ -n "$SERIES_NAME" ]] && print_status "$BLUE" "Series name: $SERIES_NAME"
[[ "$DRY_RUN" == true ]] && print_status "$YELLOW" "DRY RUN MODE - No changes will be made"
[[ "$VERBOSE" == true ]] && print_status "$CYAN" "VERBOSE MODE - Detailed output enabled"
[[ "$FORCE" == true ]] && print_status "$YELLOW" "FORCE MODE - Will overwrite existing files"
echo ""

# Main processing
rename_episode_files
rename_subtitle_files

# Show summary
show_summary

print_status "$PURPLE" "Universal Media Renamer completed successfully!"