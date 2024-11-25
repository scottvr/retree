#!/bin/bash

# Configuration and constants
declare -A OPTS=(
    [dirsonly]=0        # Only show directories
    [maxdepth]=-1       # Maximum depth (-1 for unlimited)
    [followlinks]=0     # Follow symbolic links
    [showhidden]=0      # Show hidden files
    [output_format]="tree"  # Output format: tree, paths, or json
    [input_format]="auto"   # Input format: auto, tree, paths, or ls-r
)

usage() {
    cat << EOF
Usage: $0 [OPTIONS] [directory]

Options:
    -d, --dirs-only     List directories only
    -D, --max-depth N   Limit directory recursion depth
    -f, --follow        Follow symbolic links
    -a, --all          Show hidden files
    -o, --output FORMAT Output format (tree|paths|json)
    -i, --input FORMAT  Input format (auto|tree|paths|ls-r)
    -h, --help         Show this help message

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
            -h|--help) usage ;;
            *) [[ -z "${OPTS[start_dir]}" ]] && OPTS[start_dir]="$1" ;;
        esac
        shift
    done
}

# Tree generation functions
count_indent() {
    local line="$1"
    local tree_chars
    tree_chars=$(echo "$line" | grep -o '[│├└─ ]' | tr -d '\n')
    echo "${#tree_chars}"
}

clean_line() {
    local line="$1"
    echo "$line" | sed 's/[│├└─]//g' | sed 's/^ *//' | sed 's/ *$//'
}

count_indent() {
    local line="$1"
    local tree_chars
    tree_chars=$(echo "$line" | grep -o '[│├└─ ]' | tr -d '\n')
    echo "${#tree_chars}"
}

clean_line() {
    local line="$1"
    echo "$line" | sed 's/[│├└─]//g' | sed 's/^ *//' | sed 's/ *$//'
}

check_path() {
    local path="$1"
    local name="$2"
    
    # Check full path length (4096 is common max path length for many filesystems)
    if [[ ${#path} -gt 4096 ]]; then
        printf "Skip: Path too long (%d chars): ...%s\n" "${#path}" "${path: -50}" >&2
        return 1
    fi
    
    # Check individual component length (255 is common max for many filesystems)
    if [[ ${#name} -gt 255 ]]; then
        printf "Skip: Component too long (%d chars): ...%s\n" "${#name}" "${name: -50}" >&2
        return 1
    fi
    
    return 0
}

count_indent() {
    local line="$1"
    local tree_chars
    tree_chars=$(echo "$line" | grep -o '[│├└─ ]' | tr -d '\n')
    echo "${#tree_chars}"
}

clean_line() {
    local line="$1"
    echo "$line" | sed 's/[│├└─]//g' | sed 's/^ *//' | sed 's/ *$//'
}

check_path() {
    local path="$1"
    local name="$2"
    
    # Check full path length (4096 is common max path length for many filesystems)
    if [[ ${#path} -gt 4096 ]]; then
        printf "Skip: Path too long (%d chars): ...%s\n" "${#path}" "${path: -50}" >&2
        return 1
    fi
    
    # Check individual component length (255 is common max for many filesystems)
    if [[ ${#name} -gt 255 ]]; then
        printf "Skip: Component too long (%d chars): ...%s\n" "${#name}" "${name: -50}" >&2
        return 1
    fi
    
    return 0
}

get_prefix() {
    local depth=$1
    local is_last=$2
    local prefix=""
    
    for ((i = 1; i < depth; i++)); do
        if (( ${TREE_STATE[last_entries,$i]} )); then
            prefix+="    "
        else
            prefix+="│   "
        fi
    done
    
    if ((depth > 0)); then
        if ((is_last)); then
            prefix+="└── "
        else
            prefix+="├── "
        fi
    fi
    
    echo "$prefix"
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

# Convert input paths to tree format
paths_to_tree() {
    # Arrays to track state
    declare -a paths=(".")
    declare -a indents=(-1)
    local last_depth=0
    local prev_dir=""
    
    # First, normalize and sort the input
    # This handles both find-style full paths and ls -R style output
    while IFS= read -r line; do
        # Skip empty lines and ls -R directory headers
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^.*:$ ]] && continue
        
        # Clean up the path
        # Strip leading ./ if present
        line="${line#./}"
        # Strip trailing : from directory names (ls -R format)
        line="${line%:}"
        
        # Normalize to single path format and store
        if [[ "$line" =~ ^/ ]]; then
            # Already a full path
            echo "$line"
        elif [[ "$prev_dir" != "" && ! "$line" =~ "/" ]]; then
            # ls -R format, prepend previous directory
            echo "$prev_dir/$line"
        else
            # Regular path
            echo "$line"
        fi
    done | sort | while IFS= read -r path; do
        # Skip if empty
        [[ -z "$path" ]] && continue
        
        # Calculate depth by counting slashes
        local depth=$(echo "$path" | tr -cd '/' | wc -c)
        
        # Get just the name of the current file/directory
        local name="${path##*/}"
        [[ -z "$name" ]] && continue
        
        # Determine if this is a directory (ends with /)
        local is_dir=0
        [[ "$path" =~ /$ ]] && is_dir=1
        
        # Calculate prefix based on depth
        local prefix=""
        local curr_depth=0
        while ((curr_depth < depth)); do
            if ((curr_depth == depth - 1)); then
                # Look ahead to see if this is the last entry at this level
                local next_path
                IFS= read -r next_path || next_path=""
                if [[ -n "$next_path" ]]; then
                    local next_depth=$(echo "$next_path" | tr -cd '/' | wc -c)
                    if ((next_depth <= depth)); then
                        prefix+="└── "
                    else
                        prefix+="├── "
                    fi
                else
                    prefix+="└── "
                fi
            else
                # Check if we need a vertical line or spaces
                if [[ -n "$next_path" ]] && [[ "$next_path" =~ ^"${path%/*}"/ ]]; then
                    prefix+="│   "
                else
                    prefix+="    "
                fi
            fi
            ((curr_depth++))
        done
        
        # Output the entry with proper formatting
        if ((depth == 0)); then
            echo "."
        else
            if [[ -x "$path" && ! -d "$path" ]]; then
                printf "%s%s*\n" "$prefix" "$name"
            elif ((is_dir)); then
                printf "%s%s/\n" "$prefix" "$name"
            else
                printf "%s%s\n" "$prefix" "$name"
            fi
        fi
        
        # Store the directory part for ls -R style input processing
        if ((is_dir)); then
            prev_dir="$path"
        fi
    done
}

convert_to_tree() {
    local input_format="${OPTS[input_format]}"
    [[ "$input_format" == "auto" ]] && input_format=$(detect_input_format)
    
    case "$input_format" in
        tree) cat | create_from_tree ;; # Already in tree format
        paths|ls-r) paths_to_tree | create_from_tree ;;
        *) echo "Unknown input format" >&2; exit 1 ;;
    esac
}

# Filesystem creation from tree
create_from_tree() {
    local root_dir="${OPTS[start_dir]:-.}" 
    local current_path="$root_dir"
    
    declare -a paths=("$root_dir")
    declare -a indents=(-1)
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$(echo "$line" | tr -d '[:space:]')" ]] && continue
        
        local current_indent=$(($(count_indent "$line") / 2))
        local cleaned_line
        cleaned_line=$(clean_line "$line")
        
        # Handle depth limits
        [[ ${OPTS[maxdepth]} -ge 0 ]] && [[ $current_indent -gt ${OPTS[maxdepth]} ]] && continue
        
        # Pop stack until we're at the right level
        while [[ ${indents[-1]} -ge $current_indent ]]; do
            unset 'paths[-1]'
            unset 'indents[-1]'
        done
        
        current_path="${paths[-1]}"
        
        if [[ "$cleaned_line" == */ ]]; then
            cleaned_line="${cleaned_line%/}"
            new_dir_path="$current_path/$cleaned_line"
            
            if check_path "$new_dir_path" "$cleaned_line"; then
                mkdir -p "$new_dir_path"
                paths+=("$new_dir_path")
                indents+=("$current_indent")
            fi
        elif [[ "$cleaned_line" == *"@" ]]; then
            # Handle symlinks
            cleaned_line="${cleaned_line%@}"
            new_link_path="$current_path/$cleaned_line"
            
            if check_path "$new_link_path" "$cleaned_line"; then
                # Note: Would need target path information to create actual symlinks
                touch "$new_link_path"
            fi
        else
            cleaned_line="${cleaned_line%\*}"
            new_file_path="$current_path/$cleaned_line"
            
            if check_path "$new_file_path" "$cleaned_line"; then
                touch "$new_file_path"
            fi
        fi
    done
}

# Main logic
main() {
    parse_args "$@"
    
    if [ ! -t 0 ]; then
        # Input from pipe, convert to requested format
        convert_to_tree
    else
        # Generate tree from filesystem
        generate_tree "${OPTS[start_dir]:-.}"
    fi
}

main "$@"
