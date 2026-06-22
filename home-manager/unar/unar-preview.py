#!/usr/bin/env python3

import sys

lines = sys.stdin.read().splitlines()

if not lines:
    sys.exit(0)

paths = [line.strip() for line in lines[1:] if line.strip()]

tree = {}

for path in paths:
    parts = path.split('/')

    node = tree

    for part in parts:
        if part:
            node = node.setdefault(part, {})

def print_tree(node, prefix=""):
    entries = sorted(node.keys())

    for i, name in enumerate(entries):
        is_last = (i == len(entries) - 1)

        connector = "└── " if is_last else "├── "

        print(prefix + connector + name)

        child = node[name]

        if child:
            extension = "    " if is_last else "│   "
            print_tree(child, prefix + extension)

print_tree(tree)
