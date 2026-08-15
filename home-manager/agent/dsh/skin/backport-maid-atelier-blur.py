#!/usr/bin/env python3
"""Backport the tool/think/bash blur rules into the shipped minified CSS string.

`maid-atelier/lib/client.js` is the artifact the browser actually loads: the
CSS-module pipeline compiles `src/client/maid-atelier.module.css` and inlines
the minified result as a JS string. The companion
`maid-atelier-tool-blur.patch` fixes the readable source, but this repository
ships without a lockfile, so home-manager does not rebuild the bundle here.
Instead the same overrides are appended to the tail of the inlined CSS string
(original rules come first, so the appended rules win at equal specificity).
"""

import sys
from pathlib import Path

# Keep these selectors byte-for-byte equivalent to the source patch. Attribute
# values are single-quoted so they survive the double-quoted JS string.
_EXPANDED_SELECTOR = (
    "body[data-dsh-maid-atelier] "
    ":is([data-variant]>[data-open='true'],"
    "[data-chat-flow-kind='context']>[data-slot='conversation.chat.node']>[data-open='true'])"
)
_COLLAPSED_SELECTOR = (
    "body[data-dsh-maid-atelier] "
    ":is([data-variant]>:not([data-open='true']),"
    "[data-chat-flow-kind='context']>[data-slot='conversation.chat.node']>"
    ":not([data-open='true']))>[data-disclosure-row='true']"
)
_BASH_SELECTOR = "body[data-dsh-maid-atelier] [data-variant='bash']"
_OVERRIDES = (
    f"{_EXPANDED_SELECTOR}"
    "{backdrop-filter:blur(12px) saturate(.92);"
    "-webkit-backdrop-filter:blur(12px) saturate(.92)}"
    f"{_COLLAPSED_SELECTOR}"
    "{backdrop-filter:blur(8px) saturate(.92);"
    "-webkit-backdrop-filter:blur(8px) saturate(.92)}"
    f"{_BASH_SELECTOR}"
    "{backdrop-filter:blur(8px) saturate(.92);"
    "-webkit-backdrop-filter:blur(8px) saturate(.92)}"
)

# End of the inlined CSS string inside lib/client.js. It is pinned to the
# exact upstream rev; if the upstream bundle changes this marker, this script
# must fail loudly instead of silently producing a broken artifact.
_CSS_TAIL = '}}";\n\t\tconst tagId = '


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} <maid-atelier/lib/client.js>")

    bundle = Path(sys.argv[1])
    text = bundle.read_text()

    if _CSS_TAIL not in text:
        raise SystemExit(f"{bundle}: minified CSS tail marker not found")

    if "backdrop-filter:blur(12px)" in text:
        raise SystemExit(f"{bundle}: blur overrides already present (apply to a clean source tree)")

    bundle.write_text(text.replace(_CSS_TAIL, "}}" + _OVERRIDES + '";\n\t\tconst tagId = ', 1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
