#!/bin/bash

# Function to count the indentation level based on tree characters
count_indent() {
    local line="$1"
    # Extract only the tree characters and spaces
    local tree_chars=$(echo "$line" | grep -o '[│├└─ ]' | tr -d '\n')
    # Count the characters and divide by 2 to get indent level
    echo "${#tree_chars}"
}

# Function to clean the line from tree characters
clean_line() {
    local line="$1"
    echo "$line" | sed 's/[│├└─]//g' | sed 's/^ *//' | sed 's/ *$//'
}

# Main function to process the tree and create filesystem
create_from_tree() {
    # Initialize variables
    local root_dir="${1:-.}"
    local current_path="$root_dir"
    
    # Initialize arrays for our stack
    declare -a paths=("$root_dir")
    declare -a indents=(-1)
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines
        [[ -z "$(echo "$line" | tr -d '[:space:]')" ]] && continue

        # Calculate indent level
        current_indent=$(($(count_indent "$line") / 2))
        
        # Clean the line from tree characters
        cleaned_line=$(clean_line "$line")
        
        # Check if it's a directory (ends with /)
        [[ "$cleaned_line" == */ ]] && is_directory=1 || is_directory=0
        
        # Pop from stack while indent level is less than or equal to current
        while [[ ${#paths[@]} -gt 0 && ${indents[-1]} -ge $current_indent ]]; do
            unset 'paths[-1]'
            unset 'indents[-1]'
        done
        
        # Get current path from top of stack
        current_path="${paths[-1]}"
        
        if [[ $is_directory -eq 1 ]]; then
            # Remove trailing slash for directory creation
            cleaned_line="${cleaned_line%/}"
            new_dir_path="$current_path/$cleaned_line"
            mkdir -p "$new_dir_path"
            # Push to stack
            paths+=("$new_dir_path")
            indents+=("$current_indent")
            current_path="$new_dir_path"
        else
            # Create empty file
            cleaned_line="${cleaned_line%\*}"  # Remove possible asterisk
            touch "$current_path/$cleaned_line"
        fi
    done
}

create_from_tree
