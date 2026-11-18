#!/usr/bin/env python3
"""Print the failing nodes of an .xcresult bundle as plain lines.

Used by the CI job when xcodebuild fails, so the GitHub log says which test or
which launch step actually broke instead of just "TEST FAILED". Needs the JSON
from `xcrun xcresulttool get test-results tests`.
"""
from __future__ import annotations

import json
import sys

FAILING = {"Failed", "failure", "Error"}


def walk(node: dict, depth: int = 0) -> None:
    if not isinstance(node, dict):
        return
    result = node.get("result")
    if result in FAILING or node.get("failureText"):
        name = node.get("name") or node.get("nodeType") or "?"
        detail = (node.get("failureText") or "").replace("\n", " ")[:300]
        print(f"{'  ' * depth}{name} -> {result}: {detail}")
    for child in node.get("children") or []:
        walk(child, depth + 1)


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except Exception as error:  # noqa: BLE001
        print(f"could not parse the xcresult json: {error}")
        return 0
    nodes = data.get("testNodes") or []
    if not nodes:
        print("no test nodes in the result bundle")
    for top in nodes:
        walk(top)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
