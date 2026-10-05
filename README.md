# Tabia Skills

A plugin marketplace from [Tabia Health](https://tabia.health) for [Claude Code](https://code.claude.com/docs/en/plugin-marketplaces) and [Google Antigravity](https://antigravity.google) — working knowledge about the Tabia platform, written so that a coding agent applies it the way an experienced person would.

Both Claude Code and Antigravity follow the Agent Skills format (a folder with a `SKILL.md`) and package customizations as plugins, so this repository serves both platforms.

This repository is **public**, and the plugins in it are meant for Tabia teams, customers and
partners alike. Some of what they describe still needs access you may not have — a personal
access token in the environment you are working with. Each plugin's README says what it
expects.

## Install

### Claude Code

```
/plugin marketplace add tabiahealth/skills
/plugin install tabia-cli@tabia-skills
```

Update later with:

```
/plugin marketplace update tabia-skills
```

#### Team-wide (optional)

To have Claude Code offer this marketplace to everyone who opens a given project, add to that
project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "tabia-skills": {
      "source": { "source": "github", "repo": "tabiahealth/skills" }
    }
  }
}
```

### Antigravity

Antigravity natively discovers and manages plugins across all surfaces (CLI, IDE, and 2.0).

#### Via Antigravity CLI / TUI

In an interactive session, install the plugin from a clone of this repository:

```
/plugin install ./plugins/tabia-cli
```

Or from your shell:

```bash
agy plugin install plugins/tabia-cli
```

#### Workspace-level (automatic discovery)

When working inside this repository, `.agents/plugins.json` automatically registers all plugins in `plugins/`.

To use plugins from this repository in another project, declare them in that project's `.agents/plugins.json`:

```json
{
  "entries": [
    { "path": "path/to/skills/plugins" }
  ]
}
```

Or inherit this repository's configuration:

```json
{
  "inherits": [
    { "path": "path/to/skills/.agents/plugins.json" }
  ]
}
```

#### Global (all projects)

To install globally for all Antigravity projects, link or copy the plugin into your global configuration directory:

```bash
mkdir -p ~/.gemini/config/plugins
ln -s /path/to/skills/plugins/tabia-cli ~/.gemini/config/plugins/tabia-cli
```

## Plugins

| Plugin | Description |
|---|---|
| [`tabia-cli`](plugins/tabia-cli) | Reaching a deployed Tabia environment from the command line — profiles and tokens, reading with `tabia ls` / `tabia api`, and moving pathways, flows, surveys and funnels between environments with export/plan/resolve/import. |

## A note on what these skills enforce

These skills are written for an agent, not just for a reader, so several of them carry rules
about what the agent may and may not do on your behalf. They apply the same whichever agent
runs them — Claude Code, Antigravity or another. Two run through everything here:

- **Personal data is yours to read, not the agent's.** A skill will help you write a command that
  pulls patient data into a file you own, and will decline to read those rows back into the
  conversation.
- **Irreversible steps stay with a person.** Writes to production are prepared, dry-run and
  handed over as a command for your own terminal — never completed by the agent.

## Adding a new plugin

1. `plugins/<name>/.claude-plugin/plugin.json` — Claude Code plugin manifest (`name`, `description`, `version`, `author`, `homepage`).
2. `plugins/<name>/plugin.json` — Antigravity plugin manifest (`name`, `displayName`, `description`, `version`, `suggestedPrompts`).
3. `plugins/<name>/skills/<skill-name>/SKILL.md` — the skills (commands, agents, rules, hooks and MCP configs can go in sibling directories).
4. `plugins/<name>/README.md` — what it is and what it expects of the reader.
5. Register it in `.claude-plugin/marketplace.json` for Claude Code. Antigravity automatically discovers it via `.agents/plugins.json`.
6. Open a PR.

**This repository is public.** Anything merged here is published: keep internal-only hostnames,
internal issue numbers, private repository paths and internal product code names out of it, and
write for a reader who does not work at Tabia. Internal-only skills belong in the private
[`tabiahealth/claude-skills`](https://github.com/tabiahealth/claude-skills) marketplace instead.

## Repo structure

```
.agents/
  plugins.json                      ← Antigravity plugin discovery manifest
.claude-plugin/
  marketplace.json                  ← Claude Code marketplace catalog
plugins/
  tabia-cli/
    plugin.json                     ← Antigravity plugin manifest
    .claude-plugin/plugin.json      ← Claude Code plugin manifest
    skills/
      tabia-cli/SKILL.md            ← skill (shared format)
      solution-packages/SKILL.md
    README.md
```

## License

[MIT](LICENSE) © Tabia Health
