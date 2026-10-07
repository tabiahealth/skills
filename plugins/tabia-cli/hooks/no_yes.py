"""PreToolUse hook: refuse a `tabia` command that passes --yes.

--yes skips the production confirmation, and typing the profile name there is a person
authorizing the write. An agent passing it would be authorizing the write itself. Unattended
jobs still need the flag, so the CLI cannot refuse it; this hook refuses it where an agent runs.

It reads the command as text, so it is a guard against the ordinary case, not a sandbox.
"""

import json
import re
import shlex
import sys

# A `tabia` invocation (bare, or by a path ending in /tabia), up to the next command separator.
INVOCATION = re.compile(r"(?:^|[\s;&|(`])(?:\S*/)?tabia(?=\s|$)([^;&|\n`)]*)")


def passes_yes(command: str) -> bool:
    for match in INVOCATION.finditer(command):
        try:
            words = shlex.split(match.group(1))
        except ValueError:
            words = match.group(1).split()
        if "--yes" in words:
            return True
    return False


def main() -> int:
    try:
        event = json.load(sys.stdin)
    except ValueError:
        return 0
    command = (event.get("tool_input") or {}).get("command") or ""
    if not passes_yes(command):
        return 0
    print("Blocked by the tabia-cli plugin: `--yes` skips the production confirmation, which is the "
          "person's authorization for the write, so an agent never passes it. Drop `--yes`. For a "
          "production write, run the dry run and hand the user the `--write --expect <digest>` "
          "command it printed, for their own terminal.", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main())
