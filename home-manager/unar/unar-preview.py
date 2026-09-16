#!/usr/bin/env python3

import json
import sys
from typing import Any


def load_listing() -> dict[str, Any] | None:
    """Read and validate lsar's JSON output."""
    try:
        listing = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        print(f"无法解析 lsar 输出：{error}", file=sys.stderr)
        return None

    if not isinstance(listing, dict):
        print("lsar 输出不是 JSON 对象。", file=sys.stderr)
        return None

    if "lsarError" in listing or not isinstance(listing.get("lsarContents"), list):
        print("lsar 返回了无效或不完整的压缩包列表。", file=sys.stderr)
        return None

    return listing


def is_true(value: Any) -> bool:
    if isinstance(value, str):
        return value.lower() in {"1", "true", "yes", "on"}
    return value is True or value == 1


def listing_is_encrypted(listing: dict[str, Any]) -> bool:
    properties = listing.get("lsarProperties")
    if isinstance(properties, dict) and is_true(properties.get("XADIsEncrypted")):
        return True

    contents = listing.get("lsarContents", [])
    return any(
        isinstance(entry, dict) and is_true(entry.get("XADIsEncrypted"))
        for entry in contents
    )


def display_name(name: str) -> str:
    """Keep names intact while making control characters visible."""
    return (
        name.replace("\\", "\\\\")
        .replace("\t", "\\t")
        .replace("\r", "\\r")
        .replace("\n", "\\n")
    )


def build_tree(listing: dict[str, Any]) -> dict[str, dict]:
    tree: dict[str, dict] = {}

    for entry in listing["lsarContents"]:
        if not isinstance(entry, dict):
            continue

        path = entry.get("XADFileName")
        if not isinstance(path, str) or not path:
            continue

        node = tree
        for part in path.split("/"):
            if part:
                node = node.setdefault(part, {})

    return tree


def print_tree(tree: dict[str, dict]) -> None:
    """Print the tree iteratively so very deep archives do not hit recursion limits."""
    if not tree:
        print("（压缩包为空）")
        return

    # Each frame contains sorted entries, the next index, and the display prefix.
    stack: list[tuple[list[tuple[str, dict]], int, str]] = [
        (sorted(tree.items()), 0, "")
    ]

    while stack:
        entries, index, prefix = stack[-1]
        if index >= len(entries):
            stack.pop()
            continue

        stack[-1] = (entries, index + 1, prefix)
        name, child = entries[index]
        is_last = index == len(entries) - 1
        connector = "└── " if is_last else "├── "
        print(prefix + connector + display_name(name))

        if child:
            extension = "    " if is_last else "│   "
            stack.append((sorted(child.items()), 0, prefix + extension))


def main() -> int:
    check_encrypted = sys.argv[1:] == ["--check-encrypted"]
    if sys.argv[1:] and not check_encrypted:
        print(f"未知选项：{' '.join(sys.argv[1:])}", file=sys.stderr)
        return 2

    listing = load_listing()
    if listing is None:
        return 2

    if check_encrypted:
        return 0 if listing_is_encrypted(listing) else 1

    print_tree(build_tree(listing))
    return 0


if __name__ == "__main__":
    sys.exit(main())
