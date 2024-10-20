import os
import sys

def calculate_indent(line):
    # Match both tree symbols and leading whitespace
    match = ''.join(char for char in line if char in '│├└─ ')
    char_count = len(match)

    # Divide by 2, assuming two characters represent one indentation level
    return char_count // 2

def create_from_tree(tree, root_dir="."):
    lines = [line for line in tree.splitlines() if line.strip() != '']

    current_path = root_dir
    dir_stack = [{"path": current_path, "indent": -1}]

    for line in lines:
        current_indent = calculate_indent(line)  # Calculate indent based on tree characters
        cleaned_line = ''.join(char for char in line if char not in '│├└─').strip()  # Clean up tree symbols

        #print(f'Processing line: "{line}" (cleaned: "{cleaned_line}", indent: {current_indent})')

        # Determine if this is a directory or a file
        is_directory = cleaned_line.endswith('/') # or '.' not in cleaned_line

        while dir_stack and dir_stack[-1]["indent"] >= current_indent:
            dir_stack.pop()
            # After popping, update current_path based on the new top of the stack
            current_path = dir_stack[-1]["path"] if dir_stack else root_dir

        # If the stack is not empty, update current_path to the last valid directory
        if dir_stack:
            current_path = dir_stack[-1]["path"]

        if is_directory:
            # Create the new directory
            new_dir_path = os.path.join(current_path, cleaned_line.rstrip('/'))  # Remove trailing slash
            os.makedirs(new_dir_path, exist_ok=True)
            #print(f'Created directory: {new_dir_path}')

            # Push the new directory onto the stack with its indent level
            dir_stack.append({"path": new_dir_path, "indent": current_indent})
            #print(f'Pushed to stack: {dir_stack}')

            # Update currentPath to this new directory
            current_path = new_dir_path
        else:
            # Create the file in the current directory
            file_path = os.path.join(current_path, cleaned_line.rstrip('*'))  # Join with the current directory
            with open(file_path, 'w') as f:
                pass  # Create an empty file
            #print(f'Created file: {file_path}')

if __name__ == "__main__":
    # Read from stdin and call the function
    input_tree = sys.stdin.read()
    create_from_tree(input_tree)

