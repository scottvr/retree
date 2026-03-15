#!/bin/bash

DIRS_ONLY=0
MAX_DEPTH=-1
FOLLOW_LINKS=0
SHOW_HIDDEN=0
INPUT_FORMAT="auto"
DEBUG_MODE=0
START_DIR="."

debug() {
    if [[ "$DEBUG_MODE" -eq 1 ]]; then
        echo "DEBUG: $1" >&2
    fi
}

usage() {
    cat << EOF_USAGE
Usage: $0 [OPTIONS] [directory]

Options:
    -d, --dirs-only     List directories only (generate mode)
    -D, --max-depth N   Limit directory recursion depth (generate mode)
    -f, --follow        Follow symbolic links (generate mode)
    -a, --all           Show hidden files (generate mode)
    -i, --input FORMAT  Input format hint (auto|tree|paths|ls-r)
    -h, --help          Show this help message
    --debug             Enable debug output

If stdin is piped, input is parsed into filesystem entries.
If stdin is not piped, filesystem entries are listed.
EOF_USAGE
    exit 1
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dirs-only) DIRS_ONLY=1 ;;
            -D|--max-depth) MAX_DEPTH="$2"; shift ;;
            -f|--follow) FOLLOW_LINKS=1 ;;
            -a|--all) SHOW_HIDDEN=1 ;;
            -i|--input) INPUT_FORMAT="$2"; shift ;;
            --debug) DEBUG_MODE=1 ;;
            -h|--help) usage ;;
            *) START_DIR="$1" ;;
        esac
        shift
    done
}

strip_inline_comment() {
    local line="$1"
    echo "$line" | sed -E 's/[[:space:]]+(#|;|\/\/|\/\*).*$//'
}

count_depth() {
    local line="$1"
    local prefix normalized

    prefix=$(echo "$line" | sed -E 's/^([[:space:]│├└┌┐┬┴┼╭╮╯╰─━═║╠╚╔╩╦╬|+`\\-]*).*$/\1/')
    normalized="${prefix//$'\t'/    }"
    normalized=$(echo "$normalized" | sed -E 's/[│├└┌┐┬┴┼╭╮╯╰─━═║╠╚╔╩╦╬|+`\\-]/ /g')

    echo $(( ${#normalized} / 4 ))
}

extract_entry() {
    local line="$1"
    echo "$line" | sed -E 's/^[[:space:]│├└┌┐┬┴┼╭╮╯╰─━═║╠╚╔╩╦╬|+`\\-]+//' | sed -E 's/^[[:space:]]+//' | sed -E 's/[[:space:]]+$//'
}

create_from_tree() {
    local root_dir="$START_DIR"
    local line cleaned depth entry name
    local explicit_dir explicit_symlink explicit_file executable inferred_dir is_dir
    local i last_idx parent target

    local -a names depths explicit_dirs explicit_files explicit_symlinks executables
    local -a lines
    local -a stack_paths stack_depths
    local -a errors

    local created_dirs=0
    local created_files=0

    mkdir -p "$root_dir" 2>/dev/null || true

    while IFS= read -r line || [[ -n "$line" ]]; do
        lines+=("$line")
    done


    for line in "${lines[@]}"; do
        cleaned=$(strip_inline_comment "$line")
        cleaned="${cleaned%${cleaned##*[![:space:]]}}"
        [[ -z "${cleaned//[[:space:]]/}" ]] && continue

        depth=$(count_depth "$cleaned")
        entry=$(extract_entry "$cleaned")
        [[ -z "$entry" ]] && continue

        explicit_dir=0
        explicit_symlink=0
        explicit_file=0
        executable=0

        [[ "$entry" == */ ]] && explicit_dir=1
        [[ "$entry" == *@ ]] && explicit_symlink=1
        [[ "$entry" == *\* ]] && executable=1

        if [[ $explicit_symlink -eq 1 || $executable -eq 1 || "$entry" =~ \.[^./[:space:]]+$ ]]; then
            explicit_file=1
        fi

        name="$entry"
        name="${name%/}"
        name="${name%@}"
        name="${name%\*}"

        [[ -z "$name" || "$name" == "." || "$name" == ".." ]] && continue

        names+=("$name")
        depths+=("$depth")
        explicit_dirs+=("$explicit_dir")
        explicit_files+=("$explicit_file")
        explicit_symlinks+=("$explicit_symlink")
        executables+=("$executable")
    done

    stack_paths=("$root_dir")
    stack_depths=(-1)

    for ((i = 0; i < ${#names[@]}; i++)); do
        inferred_dir=0
        if (( i + 1 < ${#names[@]} )) && (( depths[i + 1] > depths[i] )); then
            inferred_dir=1
        fi

        is_dir=0
        if (( explicit_dirs[i] == 1 )) || (( explicit_files[i] == 0 && inferred_dir == 1 )); then
            is_dir=1
        fi

        while (( ${#stack_depths[@]} > 0 )); do
            last_idx=$(( ${#stack_depths[@]} - 1 ))
            if (( stack_depths[last_idx] < depths[i] )); then
                break
            fi
            unset 'stack_depths[last_idx]'
            unset 'stack_paths[last_idx]'
            stack_depths=("${stack_depths[@]}")
            stack_paths=("${stack_paths[@]}")
        done

        if (( ${#stack_paths[@]} > 0 )); then
            parent="${stack_paths[$(( ${#stack_paths[@]} - 1 ))]}"
        else
            parent="$root_dir"
        fi

        target="$parent/${names[i]}"

        if (( is_dir == 1 )); then
            if mkdir -p "$target" 2>/dev/null; then
                created_dirs=$((created_dirs + 1))
                stack_paths+=("$target")
                stack_depths+=("${depths[i]}")
            else
                errors+=("$target: failed to create directory")
            fi
        else
            if ! mkdir -p "$parent" 2>/dev/null; then
                errors+=("$target: failed to create parent directory")
                continue
            fi
            if : > "$target" 2>/dev/null; then
                created_files=$((created_files + 1))
                if (( executables[i] == 1 )); then
                    chmod u+x "$target" 2>/dev/null || errors+=("$target: failed to set executable bit")
                fi
            else
                errors+=("$target: failed to create file")
            fi
        fi
    done

    if (( ${#errors[@]} > 0 )); then
        echo "retree: created $created_dirs dirs and $created_files files with ${#errors[@]} errors" >&2
        echo "first error: ${errors[0]}" >&2
        return 1
    fi

    return 0
}

generate_tree() {
    local dir="${1:-.}"
    local depth="${2:-0}"

    local old_dotglob old_nullglob
    old_dotglob=$(shopt -p dotglob)
    old_nullglob=$(shopt -p nullglob)

    [[ "$SHOW_HIDDEN" -eq 1 ]] && shopt -s dotglob || shopt -u dotglob
    shopt -s nullglob

    local entry is_dir
    for entry in "$dir"/*; do
        [[ ! -e "$entry" ]] && continue

        is_dir=0
        if [[ "$FOLLOW_LINKS" -eq 1 ]]; then
            [[ -d "$entry" ]] && is_dir=1
        else
            [[ -d "$entry" && ! -L "$entry" ]] && is_dir=1
        fi

        if [[ "$MAX_DEPTH" -ge 0 && "$depth" -ge "$MAX_DEPTH" ]]; then
            continue
        fi

        if [[ "$is_dir" -eq 1 ]]; then
            echo "$entry"
            generate_tree "$entry" $((depth + 1))
        elif [[ "$DIRS_ONLY" -eq 0 && -f "$entry" ]]; then
            echo "$entry"
        fi
    done

    eval "$old_dotglob"
    eval "$old_nullglob"
}

main() {
    parse_args "$@"

    if [ ! -t 0 ]; then
        debug "Input detected from pipe; parsing into filesystem"
        create_from_tree
    else
        debug "No pipe input; listing filesystem paths"
        generate_tree "$START_DIR"
    fi
}

main "$@"
