import os
import re
import stat
import sys
from typing import List, Dict, Any

COMMENT_RE = re.compile(r"\s+(?:#|;|//|/\*).*$")
LEADING_RE = re.compile(r"^[\s│├└┌┐┬┴┼╭╮╯╰─━═║╠╚╔╩╦╬|+`\\-]*")
TREE_STRIP_RE = re.compile(r"^[\s│├└┌┐┬┴┼╭╮╯╰─━═║╠╚╔╩╦╬|+`\\-]+")
TREE_CHARS_RE = re.compile(r"[│├└┌┐┬┴┼╭╮╯╰─━═║╠╚╔╩╦╬|+`\\-]")


def strip_inline_comment(line: str) -> str:
    return COMMENT_RE.sub("", line)


def count_depth(line: str) -> int:
    prefix = LEADING_RE.match(line).group(0)
    normalized = prefix.replace("\t", "    ")
    normalized = TREE_CHARS_RE.sub(" ", normalized)
    return len(normalized) // 4


def parse_line(raw_line: str) -> Dict[str, Any] | None:
    without_comment = strip_inline_comment(raw_line)
    if not without_comment.strip():
        return None

    depth = count_depth(without_comment)
    trimmed = without_comment.strip()
    entry_with_markers = TREE_STRIP_RE.sub("", trimmed).strip()
    if not entry_with_markers:
        return None

    explicit_directory = entry_with_markers.endswith("/")
    explicit_symlink = entry_with_markers.endswith("@")
    executable = entry_with_markers.endswith("*")
    has_dot_extension = bool(re.search(r"\.[^./\s]+$", entry_with_markers))
    explicit_file = explicit_symlink or executable

    name = re.sub(r"[/*@]+$", "", entry_with_markers).strip()
    if not name or name in {".", ".."}:
        return None

    return {
        "depth": depth,
        "name": name,
        "explicit_directory": explicit_directory,
        "explicit_file": explicit_file,
        "explicit_symlink": explicit_symlink,
        "executable": executable,
        "has_dot_extension": has_dot_extension,
    }


def decide_node_kinds(nodes: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    marker_style = any(node["explicit_file"] for node in nodes)

    result: List[Dict[str, Any]] = []
    for i, node in enumerate(nodes):
        next_node = nodes[i + 1] if i + 1 < len(nodes) else None
        inferred_directory = bool(next_node and next_node["depth"] > node["depth"])
        dotted_but_unmarked = node["has_dot_extension"] and not node["explicit_file"]
        treat_unmarked_dotted_as_dir = marker_style and dotted_but_unmarked and not inferred_directory
        is_directory = (
            node["explicit_directory"] or
            inferred_directory or
            treat_unmarked_dotted_as_dir
        )
        item = dict(node)
        item["is_directory"] = is_directory
        result.append(item)
    return result


def create_from_tree(tree: str, root_dir: str = ".") -> Dict[str, Any]:
    parsed_nodes = [node for node in (parse_line(line) for line in tree.splitlines()) if node is not None]
    nodes = decide_node_kinds(parsed_nodes)

    created_dirs = 0
    created_files = 0
    errors: List[str] = []

    stack = [{"path": root_dir, "depth": -1}]

    for node in nodes:
        while stack and stack[-1]["depth"] >= node["depth"]:
            stack.pop()

        parent_path = stack[-1]["path"] if stack else root_dir
        target_path = os.path.join(parent_path, node["name"])

        try:
            if node["is_directory"]:
                os.makedirs(target_path, exist_ok=True)
                created_dirs += 1
                stack.append({"path": target_path, "depth": node["depth"]})
            elif node["explicit_symlink"]:
                os.makedirs(os.path.dirname(target_path), exist_ok=True)
                with open(target_path, "w", encoding="utf-8"):
                    pass
                created_files += 1
            else:
                os.makedirs(os.path.dirname(target_path), exist_ok=True)
                with open(target_path, "w", encoding="utf-8"):
                    pass
                if node["executable"]:
                    mode = os.stat(target_path).st_mode
                    os.chmod(target_path, mode | stat.S_IXUSR)
                created_files += 1
        except OSError as error:
            errors.append(f"{target_path}: {error}")

    return {"created_dirs": created_dirs, "created_files": created_files, "errors": errors}


if __name__ == "__main__":
    input_tree = sys.stdin.read()
    result = create_from_tree(input_tree)
    if result["errors"]:
        print(
            f"retree: created {result['created_dirs']} dirs and {result['created_files']} files with {len(result['errors'])} errors",
            file=sys.stderr,
        )
        print(result["errors"][0], file=sys.stderr)
        sys.exit(1)
