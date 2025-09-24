#!/bin/bash

# Universal Media Renamer for Jellyfin/Plex - Fixed Edition
# Fixed title extraction and year handling for complex filenames
# Usage: ./rename.sh [options] [path]

set -u
set -o pipefail
IFS=$'\n\t'
shopt -s nocaseglob

# =============================================================================
# CONFIGURATION SECTION
# =============================================================================

# Default values
DRY_RUN=false
VERBOSE=false
FORCE=false
DEEP_CLEAN=false
SERIES_NAME=""
BASE_PATH="."
OUTPUT_FORMAT="Show - SxxExx - Title"
ANIME_MODE=false

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

# Title deduplication tracking
declare -A SEEN_TITLES

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_verbose() {
    [[ "$VERBOSE" == true ]] && print_status "$CYAN" "  [VERBOSE] $1" >&2
}

# Normalize text for comparison (lowercase, alphanumeric only)
normalize_text() {
    local text="$1"
    echo "$text" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+//g'
}

strip_outer_quotes() {
    local s="$1"
    if [[ "$s" =~ ^\".*\"$ ]]; then
        echo "${s:1:${#s}-2}"
    elif [[ "$s" =~ ^\'.*\'$ ]]; then
        echo "${s:1:${#s}-2}"
    else
        echo "$s"
    fi
}

# Create a safe temporary filename that works on WSL/Windows
safe_temp_path() {
    local original="$1"
    local dir=$(dirname "$original")
    local base=$(basename "$original")
    
    # Create a shorter temp name to avoid path issues
    local timestamp=$(date +%s)
    local safe_temp="$dir/.tmp_${timestamp}_$(echo "$base" | sed 's/[^a-zA-Z0-9._-]/_/g' | cut -c1-50).tmp"
    
    echo "$safe_temp"
}

# Escape special characters for use in sed regex
escape_sed() {
    local input="$1"
    local result
    result=$(printf '%s' "$input" | sed 's/[.\^$*\/\\|?+(){}[\]]/\\&/g')
    
    # If result is empty, return the input unchanged
    if [[ -z "$result" ]]; then
        printf '%s' "$input"
    else
        printf '%s' "$result"
    fi
}

usage() {
    cat << EOF
Universal Media Renamer for Jellyfin/Plex - Fixed Edition

Usage: $0 [options] [path]

Options:
  --dry-run           Show what would be renamed without making changes
  --verbose           Show detailed processing information
  --force             Overwrite existing files (use with caution)
  --anime             Enable anime/fansub mode (prioritizes anime naming patterns)
  --deep-clean        Clean internal MKV metadata and rename companion files
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
  $0 --anime --dry-run /path/to/anime/show
  $0 --anime --format "Show - SxxExx" --dry-run .

Supported Episode Patterns:
  Standard TV Shows:    S01E01, S1E1, 1x01, 01x01
  Anime/Fansub:         [Group] Show - 01 [Quality], Show - 01 [Metadata]

The script will:
1. Auto-detect series name from folder or filenames
2. Extract episode codes and normalize to S01E01 format
3. Support both standard TV and anime/fansub naming conventions
4. Clean episode titles intelligently
5. Use appropriate format based on available information
6. Handle special characters and edge cases safely

Anime Mode (--anime):
  - Prioritizes anime naming patterns (- 01 [Quality])
  - Defaults season to 01 for single-season shows
  - Changes default format to "Show - SxxExx" (no episode titles)
  - Works with fansub releases like [Erai-raws], [SubsPlease], etc.
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
    
    # In anime mode, try anime patterns first
    if [[ "$ANIME_MODE" == true ]]; then
        # Pattern: Anime/fansub style - " - 01 [" or " - 001 [" 
        if [[ "$filename" =~ -[[:space:]]+([0-9]{1,3})[[:space:]]*\[ ]]; then
            season="01"
            episode="${BASH_REMATCH[1]}"
            print_verbose "Detected anime-style episode pattern: - ${episode} ["
        # More general anime pattern - " - 01." or " - 01 "
        elif [[ "$filename" =~ -[[:space:]]+([0-9]{1,3})[[:space:]]*[\.\[] ]]; then
            season="01"
            episode="${BASH_REMATCH[1]}"
            print_verbose "Detected general anime episode pattern: - ${episode}"
        fi
    fi
    
    # Standard patterns (always try these if anime patterns didn't match)
    if [[ -z "$season" || -z "$episode" ]]; then
        # Pattern 1: S01E01, S1E1, etc.
        if [[ "$filename" =~ [Ss]([0-9]{1,2})[[:space:]_.-]*[Ee]([0-9]{1,2}) ]]; then
            season="${BASH_REMATCH[1]}"
            episode="${BASH_REMATCH[2]}"
        
        # Pattern 2: 1x01, 01x01, etc.
        elif [[ "$filename" =~ ([0-9]{1,2})x([0-9]{1,2}) ]]; then
            season="${BASH_REMATCH[1]}"
            episode="${BASH_REMATCH[2]}"
        
        # If not in anime mode, try anime patterns as fallback
        elif [[ "$ANIME_MODE" == false ]]; then
            # Pattern 3: Anime/fansub style - " - 01 [" or " - 001 [" 
            if [[ "$filename" =~ -[[:space:]]+([0-9]{1,3})[[:space:]]*\[ ]]; then
                season="01"
                episode="${BASH_REMATCH[1]}"
                print_verbose "Detected anime-style episode pattern: - ${episode} ["
            # Pattern 4: More general anime pattern - " - 01." or " - 01 "
            elif [[ "$filename" =~ -[[:space:]]+([0-9]{1,3})[[:space:]]*[\.\[] ]]; then
                season="01"
                episode="${BASH_REMATCH[1]}"
                print_verbose "Detected general anime episode pattern: - ${episode}"
            fi
        fi
    fi
    
    # Zero-pad season and episode
	if [[ -n "$season" && -n "$episode" ]]; then
		[[ ${#season} -eq 1 ]] && season="0$season"
		[[ ${#episode} -eq 1 ]] && episode="0$episode"
		# Handle 3-digit episodes like 001 -> 001 (keep as-is)
		[[ ${#episode} -eq 3 ]] && episode="$episode"
		echo "S${season}E${episode}"
	elif [[ -n "$episode" ]]; then
		# For episodes without explicit season, default to Season 01
		# (Specials handling will be done at the caller level)
		season="01"
		[[ ${#episode} -eq 1 ]] && episode="0$episode"
		[[ ${#episode} -eq 3 ]] && episode="$episode"
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
        series_no_year=$(echo "$series_name" | sed 's/ *\([0-9][0-9][0-9][0-9]\)//g')
        
        # Convert series name variations to match common filename patterns
        local series_dot="${series_no_year// /.}"
        local series_dash="${series_no_year// /-}"
        local series_under="${series_no_year// /_}"
        
        # Remove series patterns (case insensitive)
        title=$(echo "$title" | sed "s/^${series_dot}[._-]*//gI" 2>/dev/null || echo "$title")
        title=$(echo "$title" | sed "s/^${series_dash}[._-]*//gI" 2>/dev/null || echo "$title")
        title=$(echo "$title" | sed "s/^${series_under}[._-]*//gI" 2>/dev/null || echo "$title")
        title=$(echo "$title" | sed "s/^${series_no_year}[._-]*//gI" 2>/dev/null || echo "$title")
        
        # Also remove series name with year patterns (like "Doctor Who 2005")
        title=$(echo "$title" | sed "s/^${series_no_year} 2[0-9][0-9][0-9][._-]*//gI" 2>/dev/null || echo "$title")
        title=$(echo "$title" | sed "s/^${series_no_year} 19[0-9][0-9][._-]*//gI" 2>/dev/null || echo "$title")
    fi
    
    # FIXED: Better technical tag removal with word boundaries and separators
    # Remove everything after common quality/codec indicators (with proper separators)
    title=$(echo "$title" | sed -E 's/[._ -]+(720p|1080p|2160p|4K|480p|576p)([._ -].*)?$//I')
    title=$(echo "$title" | sed -E 's/[._ -]+(x264|x265|HEVC|H\.?264|H\.?265)([._ -].*)?$//I')
    title=$(echo "$title" | sed -E 's/[._ -]+(WEB(-DL)?|BluRay|BDRip|DVDRip|HDTV|PDTV)([._ -].*)?$//I')
    title=$(echo "$title" | sed -E 's/[._ -]+(AMZN|NFLX|HULU|DSNP|HBO|MAX)([._ -].*)?$//I')
    title=$(echo "$title" | sed -E 's/[._ -]+(AAC|AC3|DTS|DDP([0-9](\.[0-9])?)?)([._ -].*)?$//I')
    
    # Restore missing ws cleanup
    title=$(echo "$title" | sed 's/[._-]*ws[._-]*/ /gI')
    
    # Remove only technical parentheses, preserve meaningful ones
	title=$(echo "$title" | sed 's/([^)]*\(720p\|1080p\|2160p\|4K\|480p\|576p\|x264\|x265\|HEVC\|BluRay\|WEB\|HDTV\)[^)]*)//gI')
    title=$(echo "$title" | sed 's/\[[^]]*\]//g')
    
    # FIXED: Better release group removal (case-insensitive, handles lowercase) NEW: (only strip ALLCAPS or contains digits, 3+ chars)
    title=$(echo "$title" | sed -E 's/-([A-Z0-9]{3,}|[A-Za-z0-9]*[0-9][A-Za-z0-9]*)$//')
    
    # Remove technical abbreviations that survived
    title=$(echo "$title" | sed -E 's/(^|[._ -])(DL|DDP?)([._ -]|$)/\1\3/gI')
    
    # Remove common tags as whole words
    title=$(echo "$title" | sed 's/\b\(FIXED\|REPACK\|PROPER\|INTERNAL\|EXTENDED\|UNCUT\|DIRECTORS\|CUT\)\b//gI')
    
    # Remove file extensions
    title=$(echo "$title" | sed 's/\.mkv$//I')
    title=$(echo "$title" | sed 's/\.mp4$//I')
    title=$(echo "$title" | sed 's/\.avi$//I')
    
    # Normalize spacing and punctuation
    title=$(echo "$title" | sed 's/[._]/ /g')
    title=$(echo "$title" | sed 's/  */ /g')
    title=$(echo "$title" | sed 's/^ *//; s/ *$//')
    
    echo "$title"
}

# NEW: Safe episode title validation and cleanup
safe_episode_title() {
    local candidate_title="$1"
    local series_name="$2"
    local season="$3"
    local episode="$4"
    local file_path="$5"
    
    local title="$candidate_title"
    
    # Normalize for comparison
    local norm_title norm_series
    norm_title=$(normalize_text "$title")
    norm_series=$(normalize_text "$series_name")
    
    # Remove year from series for better comparison
    local series_no_year
    series_no_year=$(echo "$series_name" | sed 's/ *(19[0-9][0-9])//g; s/ *(2[0-9][0-9][0-9])//g')
    local norm_series_no_year
    norm_series_no_year=$(normalize_text "$series_no_year")
    
    print_verbose "Title validation: candidate='$title', series='$series_name'"
    print_verbose "Normalized: title='$norm_title', series='$norm_series', series_no_year='$norm_series_no_year'"
    
    # Drop title if it's blank, contains series name, or looks like generic episode reference
    if [[ -z "$title" ]] || \
       [[ "$norm_title" == "$norm_series" ]] || \
       [[ "$norm_title" == "$norm_series_no_year" ]] || \
       [[ "$norm_title" == *"$norm_series_no_year"* ]] || \
       [[ "$norm_series_no_year" == *"$norm_title"* ]] || \
       [[ "$norm_title" =~ ^(episode|ep)?0*[0-9]+$ ]]; then
        print_verbose "Title rejected: blank, contains/matches series name, or generic episode reference"
        title=""
    fi
    
    # If still blank and we have mediainfo, try to extract real episode title from container
    if [[ -z "$title" && -n "$file_path" ]] && command -v mediainfo >/dev/null 2>&1; then
        local media_title
        media_title=$(mediainfo --Output='General;%Title%' "$file_path" 2>/dev/null | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
        if [[ -n "$media_title" ]]; then
            local norm_media_title
            norm_media_title=$(normalize_text "$media_title")
            # Apply same checks to media title
            if [[ -n "$norm_media_title" && "$norm_media_title" != "$norm_series" && \
                  "$norm_media_title" != "$norm_series_no_year" && \
                  "$norm_media_title" != *"$norm_series_no_year"* && \
                  "$norm_series_no_year" != *"$norm_media_title"* ]]; then
                title="$media_title"
                print_verbose "Retrieved title from mediainfo: '$title'"
            fi
        fi
    fi
    
    # Deduplicate: if we've seen this normalized title before, drop it
    if [[ -n "$title" ]]; then
        local dedup_key="${season}_${norm_title}"
        if [[ -n "${SEEN_TITLES[$dedup_key]:-}" ]]; then
            print_verbose "Title rejected: duplicate within season ($title)"
            title=""
        else
            SEEN_TITLES[$dedup_key]=1
            print_verbose "Title accepted: '$title'"
        fi
    fi
    
    [[ -z "$title" && "$VERBOSE" == true ]] && print_verbose "No valid episode title found"
    
    echo "$title"
}

get_episode_title() {
    local filename="$1"
    local season_episode="$2"
    local series_name="$3"
    local file_path="$4"  # NEW: full path for mediainfo
    local title
    
    # Extract season and episode numbers for validation
    local season episode
    if [[ "$season_episode" =~ S([0-9]+)E([0-9]+) ]]; then
        season="${BASH_REMATCH[1]}"
        episode="${BASH_REMATCH[2]}"
    fi
    
    # Start with just the filename without extension
    title="${filename%.*}"
   
    # Remove season/episode patterns first
    title=$(echo "$title" | sed "s/[Ss][0-9][0-9]*[[:space:]_.-]*[Ee][0-9][0-9]*[._ -]*//")
	title=$(echo "$title" | sed "s/[Ss][0-9][0-9]*[[:space:]_.-]*[Ee][0-9][0-9]*[._ -]*//")
    title=$(echo "$title" | sed "s/[0-9][0-9]*x[0-9][0-9]*[._-]*//")
	title=$(echo "$title" | sed "s/[0-9][0-9]*x[0-9][0-9]*[._-]*//")
    
    # Remove series name and year combo (like "Doctor Who 2006")
    if [[ -n "$series_name" ]]; then
        local series_no_year series_no_year_esc
		series_no_year=$(echo "$series_name" | sed -E 's/ *\([0-9]{4}\)//g')
		series_no_year_esc=$(escape_sed "$series_no_year")
		title=$(echo "$title" | sed "s|^${series_no_year_esc} [12][0-9][0-9][0-9] *||I" 2>/dev/null || echo "$title")
		title=$(echo "$title" | sed "s|^${series_no_year_esc} *||I" 2>/dev/null || echo "$title")
		
		# If we ended up with a leading "(YYYY) - - " or "(YYYY) - ", drop it
		title=$(echo "$title" | sed -E 's/^\([12][0-9]{3}\)[[:space:]]*-[[:space:]]*-[[:space:]]*//')
		title=$(echo "$title" | sed -E 's/^\([12][0-9]{3}\)[[:space:]]*-[[:space:]]*//')
		# If we ended up with a leading "- - " (no year), drop that too
		title=$(echo "$title" | sed -E 's/^[[:space:]]*-[[:space:]]*-[[:space:]]*//')
		# De-dupe any remaining internal double separators → single " - "
		title=$(echo "$title" | sed -E 's/[[:space:]]*-[[:space:]]*-[[:space:]]*/ - /g')
    fi
    
    # IMPROVED: Better boundary detection that handles parentheses
    local clean_title=""
    
    # Look for quality indicators with dot separator (original working pattern)
    if [[ "$title" =~ ^(.+)\.(720p|1080p|2160p|4K|480p|576p) ]]; then
        clean_title="${BASH_REMATCH[1]}"
        print_verbose "Found quality boundary at '${BASH_REMATCH[2]}', title: '$clean_title'"
    # Look for quality indicators with space and opening parenthesis
    elif [[ "$title" =~ ^(.+)[[:space:]]+\((720p|1080p|2160p|4K|480p|576p) ]]; then
        clean_title="${BASH_REMATCH[1]}"
        print_verbose "Found quality boundary at '${BASH_REMATCH[2]}', title: '$clean_title'"
    # Look for other technical indicators with dot
    elif [[ "$title" =~ ^(.+)\.(WEB-DL|BluRay|BDRip|HDTV|x264|x265|HEVC) ]]; then
        clean_title="${BASH_REMATCH[1]}"
        print_verbose "Found technical boundary at '${BASH_REMATCH[2]}', title: '$clean_title'"
    # Look for other technical indicators with space and parenthesis
    elif [[ "$title" =~ ^(.+)[[:space:]]+\((WEB-DL|BluRay|BDRip|HDTV|x264|x265|HEVC) ]]; then
        clean_title="${BASH_REMATCH[1]}"
        print_verbose "Found technical boundary at '${BASH_REMATCH[2]}', title: '$clean_title'"
    # Look for platform indicators
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
    
    # Only strip a trailing (...) if it looks technical
	if [[ "$title" =~ ^(.+)[[:space:]]+\((WEB|BluRay|BDRip|HDTV|PDTV|DVDRip|AMZN|NFLX|HULU|DSNP|MAX|x264|x265|HEVC|AAC|AC3|DDP|DTS|PROPER|REPACK|INTERNAL) ]]; then
		title="${BASH_REMATCH[1]}"
		print_verbose "Removed technical parenthetical block"
	fi
    
    # Remove year at the beginning of the title
    title=$(echo "$title" | sed "s/^[12][0-9][0-9][0-9][[:space:]]*//") 
    
    # Clean the title (removes metadata, etc.)
    title=$(clean_title "$title" "$series_name")
    
    # Remove year AGAIN after cleaning, in case it survived
    title=$(echo "$title" | sed "s/^[12][0-9][0-9][0-9][[:space:]]*//") 
    
    # Final cleanup of common tags that might have survived
    title=$(echo "$title" | sed "s/\b\(FIXED\|REPACK\|PROPER\|INTERNAL\)\b//gI")
    title=$(echo "$title" | sed "s/  */ /g")
    title=$(echo "$title" | sed "s/^ *//; s/ *$//")
	
	# Remove leading/trailing dashes and spaces that might cause double dashes
	title=$(echo "$title" | sed 's/^[- ]*//; s/[- ]*$//')
    
    # Remove any trailing parenthetical content that survived - BUT preserve meaningful ones
    # First, temporarily mark meaningful parentheses to protect them
    title=$(echo "$title" | sed 's/(\([0-9]\+\))$/KEEPNUM\1KEEPNUM/')
    title=$(echo "$title" | sed 's/(Part \([0-9]\+\))$/KEEPPart\1KEEPPART/')
    title=$(echo "$title" | sed 's/(Extended Cut)$/KEEPEXTENDEDKEEP/')
    title=$(echo "$title" | sed 's/(Director[^)]*Cut)$/KEEPDIRECTORKEEP/')
    title=$(echo "$title" | sed 's/(Final Cut)$/KEEPFINALKEEP/')
    
    # Now remove any remaining trailing parentheses (these are technical)
    title=$(echo "$title" | sed 's/ *([^)]*)$//')
    
    # Restore the meaningful parentheses
    title=$(echo "$title" | sed 's/KEEPNUM\([0-9]\+\)KEEPNUM$/(\1)/')
    title=$(echo "$title" | sed 's/KEEPPart\([0-9]\+\)KEEPPART$/(Part \1)/')
    title=$(echo "$title" | sed 's/KEEPEXTENDEDKEEP$/(Extended Cut)/')
    title=$(echo "$title" | sed "s/KEEPDIRECTORKEEP$/(Director's Cut)/")
    title=$(echo "$title" | sed 's/KEEPFINALKEEP$/(Final Cut)/')
    
    # Final cleanup
    title=$(echo "$title" | sed 's/^ *//; s/ *$//')
    
    # If an unmatched '(' remains at end, drop it and the tail
    title=$(echo "$title" | sed -E 's/[[:space:]]*\([^)]*$//')
    
    # NEW: Validate the title using our safe_episode_title function
    title=$(safe_episode_title "$title" "$series_name" "$season" "$episode" "$file_path")
    
    echo "$title"
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
# METADATA CLEANUP FUNCTIONS
# =============================================================================

companion_rename() {
    local old_video="$1" 
    local new_video="$2" 
    local dry_run="$3"

    local dir old_base new_base
    dir="$(dirname "$old_video")"
    old_base="$(basename "${old_video%.*}")"
    new_base="$(basename "${new_video%.*}")"

    # Sidecar extensions we care about
    local -a exts=(srt ass vtt ssa sub idx nfo jpg jpeg png ttml txt sfv srr tbn cue xml mka mks)

    shopt -s nullglob
    for path in "$dir"/"$old_base"*; do
        # Skip the video file itself
        [[ "$path" == "$old_video" ]] && continue

        local fname ext
        fname="$(basename "$path")"
        ext="${fname##*.}"

        # Only touch files with whitelisted extensions
        if [[ ! " ${exts[*]} " =~ " ${ext} " ]]; then
            continue
        fi

        # Ensure filename starts with old base
        case "$fname" in
            "$old_base"*) ;;
            *) continue ;;
        esac

        # Preserve suffix after old base
        local suffix new_name new_path
        suffix="${fname#"$old_base"}"
        new_name="${new_base}${suffix}"
        new_path="$dir/$new_name"

        if [[ "$dry_run" == true ]]; then
            print_status "$YELLOW" "  [DRY] Would rename sidecar: $fname → $new_name"
        else
            # Ensure writable
            chmod u+w "$path" 2>/dev/null
            
            # Check if destination exists and handle appropriately
            if [[ -e "$new_path" ]]; then
                # Check if it's a case-only rename on case-insensitive filesystem
                if [[ "$(printf %s "$path" | tr '[:upper:]' '[:lower:]')" = \
                      "$(printf %s "$new_path" | tr '[:upper:]' '[:lower:]')" ]]; then
                    # Same file, different case - do the two-step rename
                    local tmp="$new_path.__tmp__"
                    if mv "$path" "$tmp" 2>/dev/null && mv "$tmp" "$new_path" 2>/dev/null; then
                        print_status "$GREEN" "  ✓ Renamed sidecar: $fname → $new_name"
                    else
                        print_status "$RED" "  ✗ Failed to rename sidecar (case hop): $fname"
                    fi
                    continue
                else
                    # Actually different file exists - skip it
                    print_verbose "Skipping existing sidecar: $new_name"
                    continue
                fi
            fi
            
            # Normal move (destination doesn't exist)
            if mv "$path" "$new_path" 2>/dev/null; then
                print_status "$GREEN" "  ✓ Renamed sidecar: $fname → $new_name"
            else
                print_status "$RED" "  ✗ Failed to rename sidecar: $fname"
            fi
        fi
    done
    shopt -u nullglob
}

deep_clean_mkv() {
    local file="$1"
    local clean_title="$2"
    local dry_run="$3"
    
    # Check if we have the required tools
    if ! command -v mkvpropedit >/dev/null 2>&1; then
        print_verbose "mkvpropedit not found - skipping internal metadata cleanup"
        return 0
    fi
	
	# Check file permissions (skip in dry-run mode)
    if [[ "$dry_run" != true ]] && ! check_file_writable "$file"; then
        print_status "$YELLOW" "  ! Skipping metadata cleanup - permission denied: $(basename "$file")"
        return 0
    fi
    
    print_verbose "Cleaning internal metadata for: $(basename "$file")"
    
    # Build single command with all edits
	local cmd=(mkvpropedit --quiet
           --edit info --set "title=$clean_title"
           --tags all:
           --edit track:@all --delete name
           "$file")
    
    if [[ "$dry_run" == true ]]; then
        print_status "$YELLOW" "  [DRY] Would clean metadata: $(basename "$file")"
        print_verbose "Command: ${cmd[*]}"
    else
        if "${cmd[@]}" 2>/dev/null; then
            print_status "$GREEN" "  ✓ Cleaned metadata: $(basename "$file")"
        else
            print_verbose "Metadata cleanup failed: $file"
        fi
    fi
}

deep_clean_mp4() {
    local file="$1"
    local clean_title="$2"
    local dry_run="$3"
    
    # Check if we have the required tools
    if ! command -v ffmpeg >/dev/null 2>&1; then
        print_verbose "ffmpeg not found - skipping MP4 metadata cleanup"
        return 0
    fi
    
    # Check current metadata to see if cleaning is needed
	local current_title=""
	if command -v mediainfo >/dev/null 2>&1; then
		current_title=$(mediainfo --Output='General;%Title%' "$file" 2>/dev/null | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
		current_title=$(strip_outer_quotes "$current_title")
		# Normalize mediainfo N/A responses to empty
		case "${current_title,,}" in
			"n/a"|"na"|"none") current_title="";;
		esac
	fi
    
    # Skip if no title or title is already clean
    if [[ -z "$current_title" || "$current_title" == "$clean_title" ]]; then
        print_verbose "MP4 metadata already clean, skipping: $(basename "$file")"
        return 0
    fi
    
    # Check if current title looks like technical metadata that should be cleaned
    local norm_current norm_clean
    norm_current=$(normalize_text "$current_title")
    norm_clean=$(normalize_text "$clean_title")
    
    # Only clean if the current title contains technical indicators or is significantly different
	local should_clean=false
	local clean_reason=""

	# Check for technical indicators
	if [[ "$norm_current" == *"720p"* || "$norm_current" == *"1080p"* || \
		"$norm_current" == *"x264"* || "$norm_current" == *"x265"* || \
		"$norm_current" == *"web"* || "$norm_current" == *"bluray"* || \
		"$norm_current" == *"hdtv"* || "$norm_current" == *"webrip"* ]]; then
		should_clean=true
		clean_reason="contains technical metadata indicators"
	elif [[ "$norm_current" != "$norm_clean"* ]]; then
		should_clean=true
		clean_reason="title differs significantly from expected clean format"
	elif [[ "$current_title" =~ ^[\'\"]. ]]; then
		should_clean=true
		clean_reason="title contains surrounding quotes indicating metadata artifacts"
	fi

	if [[ "$should_clean" != true ]]; then
		print_verbose "MP4 title looks clean, skipping: '$current_title'"
		return 0
	fi

	print_verbose "MP4 cleaning triggered: $clean_reason"
	
	# Check file permissions (skip in dry-run mode)
    if [[ "$dry_run" != true ]] && ! check_file_writable "$file"; then
        print_status "$YELLOW" "  ! Skipping metadata cleanup - permission denied: $(basename "$file")"
        return 0
    fi
    
    print_verbose "Cleaning MP4 metadata for: $(basename "$file") (current title: '$current_title')"
    
    if [[ "$dry_run" == true ]]; then
		print_status "$YELLOW" "  [DRY] Would clean MP4 metadata: $(basename "$file")"
		print_verbose "Would change title from: '$current_title' to: '$clean_title'"
	else
		local LOG_DIR="$BASE_PATH/.rename_logs"
		mkdir -p "$LOG_DIR" 2>/dev/null || true
    
		# Use a local temp file to avoid WSL path issues
		local temp_file
		temp_file=$(safe_temp_path "$file")
		local err_log="$LOG_DIR/ffmpeg_$(basename "$file" | sed 's/[^a-zA-Z0-9._-]/_/g').log"
    
		# Keep all streams; quiet errors; set title; clear global metadata
		local cmd=(ffmpeg -hide_banner -nostdin -v error -i "$file" \
			-map 0 -c copy -map_metadata -1 \
			-metadata "title=$clean_title" \
			-movflags use_metadata_tags \
			-y "$temp_file")
    
		if "${cmd[@]}" 2>"$err_log"; then
			if mv "$temp_file" "$file" 2>/dev/null; then
				print_status "$GREEN" "  ✓ Cleaned MP4 metadata: $(basename "$file")"
				rm -f "$err_log" 2>/dev/null
			else
				print_status "$RED" "  ✗ Failed to replace file: $(basename "$file")"
				rm -f "$temp_file" 2>/dev/null
				print_verbose "See error log: $err_log"
			fi
		else
			# Try AtomicParsley as fallback if available
			if command -v AtomicParsley >/dev/null 2>&1; then
				print_verbose "ffmpeg failed; attempting AtomicParsley fallback"
				if AtomicParsley "$file" --title "$clean_title" --overWrite 2>>"$err_log"; then
					print_status "$GREEN" "  ✓ Cleaned MP4 metadata with AtomicParsley: $(basename "$file")"
					rm -f "$err_log" 2>/dev/null
				else
					print_status "$RED" "  ✗ Failed to clean MP4 metadata: $(basename "$file")"
					local reason
					reason=$(tail -n 3 "$err_log" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g')
					[[ -n "$reason" ]] && print_verbose "Reason: $reason"
					print_verbose "Full log: $err_log"
				fi
			else
				print_status "$RED" "  ✗ Failed to clean MP4 metadata: $(basename "$file")"
				local reason
				reason=$(tail -n 3 "$err_log" | tr '\n' ' ' | sed -E 's/[[:space:]]+/ /g')
				[[ -n "$reason" ]] && print_verbose "Reason: $reason"
				print_verbose "Full log: $err_log"
			fi
			rm -f "$temp_file" 2>/dev/null
		fi
	fi
}

# Generic metadata cleanup function
deep_clean_metadata() {
    local file="$1"
    local clean_title="$2"
    local dry_run="$3"
    
    local extension="${file##*.}"
    extension="${extension,,}" # convert to lowercase
    
    case "$extension" in
        mkv)
            deep_clean_mkv "$file" "$clean_title" "$dry_run"
            ;;
        mp4|m4v)
            deep_clean_mp4 "$file" "$clean_title" "$dry_run"
            ;;
        *)
            print_verbose "Deep clean not supported for .$extension files"
            ;;
    esac
}

check_file_writable() {
    local file="$1"
    
    # Check if file exists and is writable
    if [[ ! -w "$file" ]]; then
        print_verbose "File not writable, attempting to fix permissions: $(basename "$file")"
        
        # Try to add write permission
        if chmod u+w "$file" 2>/dev/null; then
            print_verbose "Fixed permissions for: $(basename "$file")"
            return 0
        else
            print_verbose "Could not fix permissions for: $(basename "$file")"
            return 1
        fi
    fi
    
    return 0
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
    
    # In the "already correct" section, add this line:
	if [[ "$old_path" == "$new_path" ]]; then
		print_status "$GREEN" "  ✓ Already correct: $(basename "$new_path")"

		# Still handle companion files and metadata cleanup for video files
		if [[ "$type" == "file" ]]; then
			companion_rename "$old_path" "$new_path" "$DRY_RUN"
			if [[ "$DEEP_CLEAN" == true ]]; then
				deep_clean_metadata "$new_path" "$(basename "${new_path%.*}")" "$DRY_RUN"
			fi
		fi
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
        
        # Handle companion files and metadata cleanup in dry run mode
        if [[ "$type" == "file" ]]; then
            companion_rename "$old_path" "$new_path" true
            if [[ "$DEEP_CLEAN" == true ]]; then
                deep_clean_metadata "$new_path" "$(basename "${new_path%.*}")" true
            fi
        fi
    else
        # Handle case-only renames on case-insensitive filesystems
		if [[ -e "$new_path" ]] && \
		   [[ "$(tr '[:upper:]' '[:lower:]' <<<"$old_path")" = "$(tr '[:upper:]' '[:lower:]' <<<"$new_path")" ]] && \
		   [[ "$old_path" != "$new_path" ]]; then
			local tmp="${new_path}.__tmp__"
			if mv "$old_path" "$tmp" 2>/dev/null && mv "$tmp" "$new_path" 2>/dev/null; then
				print_status "$GREEN" "  ✓ Renamed $type (case hop): $(basename "$old_path") → $(basename "$new_path")"
				# Handle companion files and metadata cleanup for video files
				if [[ "$type" == "file" ]]; then
					companion_rename "$old_path" "$new_path" "$DRY_RUN"
					if [[ "$DEEP_CLEAN" == true ]]; then
						deep_clean_metadata "$new_path" "$(basename "${new_path%.*}")" "$DRY_RUN"
					fi
				fi
				return 0
			else
				print_status "$RED" "  ✗ Failed to rename $type (case hop): $(basename "$old_path")"
				return 1
			fi
		elif mv "$old_path" "$new_path" 2>/dev/null; then
			print_status "$GREEN" "  ✓ Renamed $type: $(basename "$old_path") → $(basename "$new_path")"
			
			# Handle companion files and metadata cleanup for video files
			if [[ "$type" == "file" ]]; then
				companion_rename "$old_path" "$new_path" "$DRY_RUN"
				if [[ "$DEEP_CLEAN" == true ]]; then
					deep_clean_metadata "$new_path" "$(basename "${new_path%.*}")" "$DRY_RUN"
				fi
			fi
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
    while IFS= read -r -d '' file; do
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
		# Handle Specials folders - override season to 00
		# Handle Specials folders - override season to 00
		if [[ -n "$season_episode" ]] && [[ "$(basename "$file_dir")" =~ ^[Ss]pecials?$ ]]; then
			# Force S00 regardless of what season was parsed
			season_episode="S00E${season_episode##*E}"
			print_verbose "Detected Specials folder, using season 00: $season_episode"
		fi
        if [[ -z "$season_episode" ]]; then
            print_status "$RED" "  ✗ Could not extract episode info from: $file_name"
            continue
        fi
        print_verbose "Extracted season/episode: $season_episode"
        
        # Extract episode title - NOW PASSING THE FULL FILE PATH
        local episode_title
        episode_title=$(get_episode_title "$file_name" "$season_episode" "$detected_series" "$file")
        print_verbose "Extracted episode title: '$episode_title'"
        
        # Format the new filename
        local new_file_name
        new_file_name=$(build_filename "$season_episode" "$episode_title" "$extension" "$detected_series")
        local new_file_path="$file_dir/$new_file_name"
        print_verbose "Formatted filename: '$new_file_name'"
        
		print_verbose "About to call safe_rename: old='$file' new='$new_file_path'"
		
        if safe_rename "$file" "$new_file_path" "file"; then
            renamed_count=$((renamed_count + 1))
        fi
        
	done < <(find "$BASE_PATH" -type f \( -iname '*.mkv' -o -iname '*.mp4' -o -iname '*.avi' -o -iname '*.m4v' -o -iname '*.mov' -o -iname '*.wmv' -o -iname '*.flv' -o -iname '*.webm' -o -iname '*.ts' -o -iname '*.m2ts' \) -print0 2>/dev/null)
    
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
    while IFS= read -r -d '' file; do
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
		if [[ "$base_name" =~ \.([A-Za-z]{2,4}|[A-Za-z]{2,3}-[A-Za-z]{2,3}|forced)$ ]]; then
			lang_code="${BASH_REMATCH[1]}"
			lang_code="${lang_code,,}"   # normalize to lowercase
			print_verbose "Detected language code: $lang_code"
		fi
        
        # Find matching video file to use its exact title
        local video_base=""
        while IFS= read -r -d '' v; do
            local bn="$(basename "${v%.*}")"
            if [[ "$bn" =~ (^|[^0-9])$season_episode([^0-9]|$) ]]; then
                video_base="$bn"
                print_verbose "Found matching video: '$bn'"
                break
            fi
        done < <(find "$file_dir" -maxdepth 1 -type f \
                  \( -iname '*.mkv' -o -iname '*.mp4' -o -iname '*.avi' -o -iname '*.m4v' \
                     -o -iname '*.mov' -o -iname '*.wmv' -o -iname '*.flv' -o -iname '*.webm' \
                     -o -iname '*.ts' -o -iname '*.m2ts' \) -print0 2>/dev/null)
        
        # Build new filename using video's exact name if available
        local base_new_name
        if [[ -n "$video_base" ]]; then
            base_new_name="$video_base"
            print_verbose "Using existing video title: '$video_base'"
        else
            # Extract episode title - ALSO PASSING FULL PATH FOR SUBTITLES
            local episode_title
            episode_title=$(get_episode_title "$file_name" "$season_episode" "$detected_series" "$file")
            print_verbose "Extracted episode title: '$episode_title'"
            
            # Format the new filename
            base_new_name=$(build_filename "$season_episode" "$episode_title" "" "$detected_series")
            base_new_name="${base_new_name%.*}"  # Remove empty extension added by build_filename
        fi
        
        # Add language code if present
        local new_file_name
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
            continue  # Skip the safe_rename call
        fi
        
        if safe_rename "$file" "$new_file_path" "subtitle"; then
            renamed_count=$((renamed_count + 1))
        fi
        
    done < <(find "$BASE_PATH" -type f \( -iname '*.srt' -o -iname '*.sub' -o -iname '*.ass' -o -iname '*.ssa' -o -iname '*.vtt' \) -print0 2>/dev/null)
	
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
        --anime)
            ANIME_MODE=true
            [[ "$OUTPUT_FORMAT" == "Show - SxxExx - Title" ]] && OUTPUT_FORMAT="Show - SxxExx"
            shift
            ;;
        --deep-clean)
            DEEP_CLEAN=true
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
                "Show "*" - SxxExx - Title"|"Show "*" - SxxExx"|"Show - SxxExx - Title"|"Show - SxxExx"|"SxxExx - Title"|"SxxExx")
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
[[ "$DEEP_CLEAN" == true ]] && print_status "$PURPLE" "DEEP CLEAN MODE - Will clean metadata and rename companion files"
echo ""

# Main processing
rename_episode_files
rename_subtitle_files

# Show summary
show_summary

print_status "$PURPLE" "Universal Media Renamer completed successfully!"