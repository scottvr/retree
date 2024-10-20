#!/bin/bash

count_indent() {
    local line="$1"
    local tree_chars=$(echo "$line" | grep -o '[│├└─ ]' | tr -d '\n')
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

create_from_tree() {
    local root_dir="${1:-.}"
    local current_path="$root_dir"
    
    declare -a paths=("$root_dir")
    declare -a indents=(-1)
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$(echo "$line" | tr -d '[:space:]')" ]] && continue

        local current_indent=$(($(count_indent "$line") / 2))
        local cleaned_line=$(clean_line "$line")
        
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
        else
            cleaned_line="${cleaned_line%\*}"
            new_file_path="$current_path/$cleaned_line"
            
            if check_path "$new_file_path" "$cleaned_line"; then
                touch "$new_file_path"
            fi
        fi
    done
}

create_from_tree
