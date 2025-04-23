#!/bin/bash

# Configuration and constants
declare -A OPTS=(
    [dirsonly]=0        # Only show directories
    [maxdepth]=-1       # Maximum depth (-1 for unlimited)
    [followlinks]=0     # Follow symbolic links
    [showhidden]=0      # Show hidden files
    [output_format]="tree"  # Output format: tree, paths, or json
    [input_format]="auto"   # Input format: auto, tree, paths, or ls-r
    [debug]=0           # Enable debug output (0=off, 1=on)
)

# Debug function
debug() {
    if [ ${OPTS[debug]} -eq 1 ]; then
        echo "DEBUG: $1" >&2
    fi
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS] [directory]

Options:
    -d, --dirs-only     List directories only
    -D, --max-depth N   Limit directory recursion depth
    -f, --follow        Follow symbolic links
    -a, --all           Show hidden files
    -o, --output FORMAT Output format (tree|paths|json)
    -i, --input FORMAT  Input format (auto|tree|paths|ls-r)
    -h, --help          Show this help message
    --debug             Enable debug output

Input can be provided via stdin for conversion operations.
EOF
    exit 1
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dirs-only) OPTS[dirsonly]=1 ;;
            -D|--max-depth) OPTS[maxdepth]="$2"; shift ;;
            -f|--follow) OPTS[followlinks]=1 ;;
            -a|--all) OPTS[showhidden]=1 ;;
            -o|--output) OPTS[output_format]="$2"; shift ;;
            -i|--input) OPTS[input_format]="$2"; shift ;;
            --debug) OPTS[debug]=1 ;;
            -h|--help) usage ;;
            *) [[ -z "${OPTS[start_dir]}" ]] && OPTS[start_dir]="$1" ;;
        esac
        shift
    done
}

detect_input_format() {
    read -r first_line

    # Set the start_dir option if the format is recognized as tree
    if [[ "$first_line" =~ ^[│├└─] ]]; then
        OPTS[input_format]="tree"
        OPTS[start_dir]="$first_line"
    elif [[ "$first_line" =~ ^.*:$ ]]; then
        OPTS[input_format]="ls-r"
    elif [[ "$first_line" =~ ^\.?/ ]]; then
        OPTS[input_format]="paths"
    elif [[ "$first_line" =~ ^/?[^/]+/$ ]]; then
        OPTS[input_format]="tree"
        OPTS[start_dir]="$first_line"  # Use first line as start_dir
    else
        OPTS[input_format]="unknown"
    fi

    # Echo the input format for further processing
    echo "${OPTS[input_format]}"
}

# More accurate level detection by counting the tree symbols
get_level() {
    local line="$1"
    
    # First, normalize the line by replacing all spaces with single space
    local normalized=$(echo "$line" | sed 's/  */ /g')
    
    # Count vertical bars and branch markers
    local vertical_bars=$(echo "$line" | grep -o "│" | wc -l)
    local branch_markers=$(echo "$line" | grep -o "[├└]" | wc -l)
    
    # The level is the sum of tree symbols
    local level=$((vertical_bars + branch_markers))
    
    debug "Level for '$line': $level (│:$vertical_bars, [├└]:$branch_markers)"
    
    echo $level
}

# Extract just the filename/dirname from a tree line
get_name() {
    local line="$1"
    
    # Try specific pattern matching first
    if [[ "$line" =~ [├└]──[[:space:]]+([^[:space:]].*) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        # Remove tree symbols and leading/trailing whitespace
        echo "$line" | sed 's/^[│├└]//g' | sed 's/^──//g' | sed 's/^[[:space:]]*//g' | sed 's/[[:space:]]*$//g'
    fi
}

# Filesystem creation from tree - FINAL VERSION
create_from_tree() {
    local root_dir="${OPTS[start_dir]:-.}" 
    debug "Root directory: $root_dir"
    
    # Create the root directory
    mkdir -p "$root_dir"
    
    # Process first line if it's a root directory name
    local first_line
    IFS= read -r first_line || true
    
    # If first line doesn't start with tree symbols and looks like a directory name
    if [[ -n "$first_line" && ! "$first_line" =~ ^[│├└] ]]; then
        # Remove comments
        first_line="${first_line%%#*}"
        first_line="${first_line%"${first_line##*[![:space:]]}"}"  # trim trailing space
        
        if [[ -n "$first_line" ]]; then
            if [[ "$first_line" =~ .*/ ]]; then
                # Use as root directory
                root_dir="$root_dir/$(echo "$first_line" | sed 's#/$##')"
                mkdir -p "$root_dir"
                debug "Using first line as root directory: $root_dir"
            fi
        fi
    else
        # Put back the first line for processing
        exec 3<&0
        exec 0< <(echo "$first_line"; cat <&3)
    fi
    
    # Maps for tracking directories at each level
    declare -A level_dirs
    level_dirs[0]="$root_dir"
    
    # Track the last level for each path component
    declare -A path_levels
    
    # Process all lines
    local line_num=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))
        
        # Skip empty lines
        [[ -z "$line" ]] && continue
        
        # Remove comments (full-line or inline)
        line="${line%%#*}"
        line="${line%"${line##*[![:space:]]}"}"  # trim trailing space
        
        # Skip if empty after removing comments
        [[ -z "$line" ]] && continue
        
        # Determine the level and name
        local level=$(get_level "$line")
        local name=$(get_name "$line")
        
        debug "Line $line_num: '$line' -> Level: $level, Name: '$name'"
        
        # Skip if beyond max depth
        if [[ ${OPTS[maxdepth]} -ge 0 ]] && [[ $level -gt ${OPTS[maxdepth]} ]]; then
            debug "  Skipping due to max depth"
            continue
        fi
        
        # Determine the parent directory
        local parent_level=$((level - 1))
        if [[ $parent_level -lt 0 ]]; then
            parent_level=0
        fi
        
        local parent_dir="${level_dirs[$parent_level]}"
        debug "  Parent level: $parent_level, Parent dir: $parent_dir"
        
        # Process based on item type
        if [[ "$name" == */ ]]; then
            # It's a directory (ends with /)
            local dir_name="${name%/}"  # Remove trailing slash
            local full_path="$parent_dir/$dir_name"
            
            debug "  Creating directory: $dir_name at $full_path"
            mkdir -p "$full_path"
            
            # Store this directory for its level
            level_dirs[$level]="$full_path"
            
            # Store the path component's level
            path_levels["$full_path"]=$level
            
            debug "  Stored dir for level $level: $full_path"
        elif [[ "$name" == *"@" ]]; then
            # It's a symlink (ends with @)
            local link_name="${name%@}"  # Remove @ symbol
            local full_path="$parent_dir/$link_name"
            
            debug "  Creating symlink file: $link_name at $full_path"
            touch "$full_path"  # Just create a regular file since we don't have target info
        else
            # It's a regular file
            local file_name="$name"
            # Check for executable marker
            if [[ "$file_name" == *\* ]]; then
                file_name="${file_name%\*}"  # Remove asterisk
            fi
            
            local full_path="$parent_dir/$file_name"
            
            debug "  Creating file: $file_name at $full_path"
            touch "$full_path"
            
            # Make executable if it had the asterisk
            if [[ "$name" == *\* ]]; then
                chmod +x "$full_path"
            fi
        fi
    done
}

# Simple paths_to_tree function 
paths_to_tree() {
    cat
}

convert_to_tree() {
    local input_format="${OPTS[input_format]}"
    [[ "$input_format" == "auto" ]] && input_format=$(detect_input_format)
    
    debug "Input format: $input_format"
    
    case "$input_format" in
        tree) 
            debug "Using tree format"
            cat | create_from_tree
            ;;
        paths|ls-r) 
            debug "Converting from paths/ls-r format"
            paths_to_tree | create_from_tree
            ;;
        *) 
            echo "Unknown input format" >&2
            exit 1
            ;;
    esac
}

# generate_tree: Pure bash version replacing find, for irony and independence
# The original version used:
# generate_tree() {
#     local dir="${1:-.}"
#     echo "Directory: $dir"
#     find "$dir" -type f -o -type d | sort
# }
# But since this whole thing started as a joke about NOT using anything but bash...
# here's a version that does it the hard way

generate_tree() {
    local dir="${1:-.}"
    local indent="${2:-}"

    shopt -s nullglob dotglob  # Include hidden files and handle empty globs

    for entry in "$dir"/*; do
        if [[ ${OPTS[dirsonly]} -eq 1 && -f "$entry" ]]; then
            continue
        fi
        if [[ -d "$entry" ]]; then
            echo "$entry"
            generate_tree "$entry"
        elif [[ -f "$entry" ]]; then
            echo "$entry"
        fi
    done

    shopt -u nullglob dotglob
}

main() {
    parse_args "$@"
    
    if [ ! -t 0 ]; then
        # Input from pipe, convert to requested format
        debug "Input detected from pipe"
        convert_to_tree
    else
        # Generate tree from filesystem
        debug "No pipe input, generating tree"
        generate_tree "${OPTS[start_dir]:-.}"
    fi
}

main "$@"
