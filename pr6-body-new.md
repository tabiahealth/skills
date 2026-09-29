## Changes

- **Funnels in the `tabia-cli` skill:** `export --funnel`, `ls funnel` (published only), and what an import meets: a funnel arrives as an unpublished draft, an unpublished one stays a reference, and a flow or funnel name the target already holds is reported by the dry run before anything is sent, with the two ways out (`--rename`, or pointing the package at the existing one through the map) and the instruction that the choice is the user's.
- **Funnels in the `solution-packages` skill:** funnels join the kinds that being referenced pulls in, the "what each kind arrives as" table gets a funnel row, and the name rule sits next to the flow's and says how a clash is resolved on import.
- **Keyring troubleshooting:** a row for `secret-tool is installed, but no keyring is answering it`, and the plaintext row now says the CLI creates the file itself and that `TABIA_ALLOW_PLAINTEXT_TOKENS=1` has to be set on every command.
- Plugin, marketplace and README descriptions mention funnels.

## Merge order

This describes behaviour that is not live yet, so it waits for:

- tabiahealth/tabia-cli#10, which adds the funnel commands and the name check before an import (tabiahealth/tabia-cli#9, the keyring handling, is merged), and
- tabiahealth/careos#15561, which makes the package carry funnels at all.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

