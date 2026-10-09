"""PreToolUse hook: refuse a `tabia` command that passes --yes.

--yes skips the production confirmation, and typing the profile name there is a person
authorizing the write. An agent passing it would be authorizing the write itself. Unattended
jobs still need the flag, so the CLI cannot refuse it; this hook refuses it where an agent runs.

It reads the command the way a shell splits it, so it is a guard against the ordinary case,
not a sandbox: a command built at run time (`eval`, a variable holding the flag) gets past it.
"""

import json
import os
import re
import shlex
import sys

SEPARATORS = set("();<>|&\n")
# Words that run the command after them, so the command position moves past them.
PREFIXES = {"command", "exec", "env", "nohup", "time", "sudo", "xargs"}
SHELLS = {"sh", "bash", "zsh", "dash"}
# `python3 ./tabia …` runs the CLI too: the script is the first word after the interpreter's options.
INTERPRETERS = re.compile(r"(python|pypy)[0-9.]*")
INTERPRETER_OPTIONS_WITH_VALUE = {"-W", "-X"}
# argparse takes any unambiguous prefix of a long option, so `--y` and `--ye` mean `--yes`.
YES_SPELLINGS = {"--y", "--ye", "--yes"}
# `$(…)` and `…`, which a shell runs as command lines of their own even inside double quotes.
SUBSTITUTIONS = re.compile(r"\$\(([^()]*)\)|`([^`]*)`")


def tokens(command: str) -> list:
    lexer = shlex.shlex(command, posix=True, punctuation_chars="();<>|&\n")
    lexer.whitespace = " \t\r"
    lexer.whitespace_split = True
    try:
        return list(lexer)
    except ValueError:              # unbalanced quotes: the shell would refuse it too
        return command.split()


def segments(words: list) -> list:
    """The simple commands in a command line, split at its operators."""
    found, current = [], []
    for word in words:
        if word and set(word) <= SEPARATORS:
            found.append(current)
            current = []
        else:
            current.append(word)
    return found + [current]


def script_and_arguments(words: list) -> list:
    """What follows an interpreter's own options: the script it runs, then that script's arguments."""
    while words and words[0].startswith("-"):
        if words[0] in ("-", "-c", "-m"):     # stdin, inline code or a module: no script file
            return []
        words = words[2:] if words[0] in INTERPRETER_OPTIONS_WITH_VALUE else words[1:]
    return words


def passes_yes(command: str, depth: int = 0) -> bool:
    if depth < 3 and any(passes_yes(inner, depth + 1)
                         for match in SUBSTITUTIONS.finditer(command)
                         for inner in match.groups() if inner):
        return True
    for words in segments(tokens(SUBSTITUTIONS.sub(" ", command))):
        while words and ("=" in words[0] and not words[0].startswith("=")
                         or words[0] in PREFIXES):
            words = words[1:]
        if not words:
            continue
        program = os.path.basename(words[0])
        if INTERPRETERS.fullmatch(program):
            script = script_and_arguments(words[1:])
            if script and os.path.basename(script[0]) == "tabia" and YES_SPELLINGS & set(script[1:]):
                return True
        if program == "tabia" and YES_SPELLINGS & set(words[1:]):
            return True
        # `bash -c "tabia … --yes"` runs a command line of its own.
        if program in SHELLS and "-c" in words[1:-1] and depth < 3:
            if passes_yes(words[words.index("-c") + 1], depth + 1):
                return True
    return False


def main() -> int:
    try:
        event = json.load(sys.stdin)
    except json.JSONDecodeError as error:
        # Not blocking: a hook that cannot read its input would otherwise stop every command.
        # Exit 1 reports the failure instead of passing silently.
        print(f"tabia-cli plugin: the --yes guard could not read the hook input ({error}); "
              "this command was not checked.", file=sys.stderr)
        return 1
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
