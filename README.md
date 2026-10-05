# Tabia Skills

Agent skills from [Tabia Health](https://tabia.health) — working knowledge about the Tabia
platform, written so that a coding agent applies it the way an experienced person would.

The repository is a [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces),
and the same skills install in Google's [Gemini CLI](https://github.com/google-gemini/gemini-cli):
both follow the Agent Skills format, a folder with a `SKILL.md`, so one copy serves both.

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

### Gemini CLI

Gemini CLI installs a skill straight from this repository, one skill per command:

```
gemini skills install https://github.com/tabiahealth/skills.git --path plugins/tabia-cli/skills/tabia-cli --consent
gemini skills install https://github.com/tabiahealth/skills.git --path plugins/tabia-cli/skills/solution-packages --consent
```

They install for your user by default; add `--scope workspace` to install them for the current
project only. `--consent` skips the interactive confirmation. `gemini skills list` shows what
is installed. See Gemini CLI's
[skills documentation](https://github.com/google-gemini/gemini-cli/blob/main/docs/cli/skills.md)
for the rest.

## Plugins

| Plugin | Description |
|---|---|
| [`tabia-cli`](plugins/tabia-cli) | Reaching a deployed Tabia environment from the command line — profiles and tokens, reading with `tabia ls` / `tabia api`, and moving pathways, flows, surveys and funnels between environments with export/plan/resolve/import. |

## A note on what these skills enforce

These skills are written for an agent, not just for a reader, so several of them carry rules
about what the agent may and may not do on your behalf. They apply the same whichever agent
runs them — Claude Code, Gemini CLI or another. Two run through everything here:

- **Personal data is yours to read, not the agent's.** A skill will help you write a command that
  pulls patient data into a file you own, and will decline to read those rows back into the
  conversation.
- **Irreversible steps stay with a person.** Writes to production are prepared, dry-run and
  handed over as a command for your own terminal — never completed by the agent.

## Adding a new plugin

1. `plugins/<name>/.claude-plugin/plugin.json` — manifest (`name`, `description`, `version`,
   `author`, `homepage`).
2. `plugins/<name>/skills/<skill-name>/SKILL.md` — the skill itself (commands, agents and hooks
   can go in sibling `commands/`, `agents/`, `hooks/` directories the same way).
3. `plugins/<name>/README.md` — what it is and what it expects of the reader.
4. Register it in `.claude-plugin/marketplace.json` (`name`, `source: "./plugins/<name>"`, and a
   short `description`).
5. Open a PR.

**This repository is public.** Anything merged here is published: keep internal-only hostnames,
internal issue numbers, private repository paths and internal product code names out of it, and
write for a reader who does not work at Tabia. Internal-only skills belong in the private
[`tabiahealth/claude-skills`](https://github.com/tabiahealth/claude-skills) marketplace instead.

## Repo structure

```
.claude-plugin/marketplace.json     ← catalog of every plugin in this repo
plugins/
  tabia-cli/
    .claude-plugin/plugin.json      ← plugin manifest
    skills/tabia-cli/SKILL.md       ← the skill
    README.md
```

## License

[MIT](LICENSE) © Tabia Health
