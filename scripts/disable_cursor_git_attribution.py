#!/usr/bin/env python3
import json
from pathlib import Path


def main() -> int:
    path = Path.home() / ".cursor" / "cli-config.json"
    if not path.exists():
        print("SKIP  cursor attribution (missing ~/.cursor/cli-config.json)")
        return 0

    try:
        data = json.loads(path.read_text())
    except Exception as e:
        print(f"WARN  cursor attribution (failed to parse {path}: {e})")
        return 0

    attr = data.get("attribution") or {}

    changed = False
    if attr.get("attributeCommitsToAgent") is not False:
        attr["attributeCommitsToAgent"] = False
        changed = True
    if attr.get("attributePRsToAgent") is not False:
        attr["attributePRsToAgent"] = False
        changed = True

    data["attribution"] = attr

    if changed:
        path.write_text(json.dumps(data, indent=2) + "\n")
        print("OK    cursor attribution disabled")
    else:
        print("OK    cursor attribution already disabled")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
