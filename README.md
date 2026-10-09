# Tabia Skills

Agent skills from [Tabia Health](https://tabia.health) — working knowledge about the Tabia
platform, written so that a coding agent applies it the way an experienced person would.

The repository is a [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces),
and the same plugin folders install in Google's [Antigravity](https://antigravity.google). Both
read the Agent Skills format, a folder with a `SKILL.md`, so one copy of each skill serves
every agent.

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

Install straight from this repository with the `agy` CLI:

```bash
agy plugin install https://github.com/tabiahealth/skills
```

`agy` clones the repository, finds the `plugins/` folder and installs every plugin in it
into `~/.gemini/config/plugins/`, where Antigravity reads plugins in every workspace. Run
the same command again to update. `agy plugin list` shows what is installed.

For a single project only, copy the plugin folder into `.agents/plugins/` at that project's
root instead. See Antigravity's [plugins documentation](https://antigravity.google/docs/plugins/)
for the rest.

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

1. `plugins/<name>/.claude-plugin/plugin.json` — the Claude Code manifest (`name`,
   `description`, `version`, `author`, `homepage`). Set `version` once, here; after that it
   belongs to the release PR (see below).
2. `plugins/<name>/plugin.json` — the Antigravity manifest (`$schema`, `name`,
   `description`). Keep its `name` and `description` identical to the Claude Code manifest's;
   when you change one, change the other.
3. `plugins/<name>/skills/<skill-name>/SKILL.md` — the skill itself (commands, agents and hooks
   can go in sibling `commands/`, `agents/`, `hooks/` directories the same way).
4. `plugins/<name>/README.md` — what it is and what it expects of the reader.
5. Register it in `.claude-plugin/marketplace.json` (`name`, `source: "./plugins/<name>"`, and a
   short `description`). Antigravity installs from the folder itself, so there is nothing to
   register for it.
6. Open a PR.

## Releasing

Claude Code delivers a plugin update only when the plugin's `version` changes, but nobody edits
`version` by hand: a PR that changes it fails the `version-guard` check.

1. Merge your change to a plugin as usual, without touching `version`.
2. A release PR, `Release <plugin> <version>`, appears or updates itself. It bumps the minor
   version by default and lists every PR it includes. To ask for another bump, put a
   `release: patch` or `release: major` label on your PR; the largest one asked for wins.
3. Merging the release PR is what ships the update to users. Until then the changes sit on
   `main` unreleased.

**This repository is public.** Anything merged here is published: keep internal-only hostnames,
internal issue numbers, private repository paths and internal product code names out of it, and
write for a reader who does not work at Tabia. Internal-only skills belong in the private
[`tabiahealth/claude-skills`](https://github.com/tabiahealth/claude-skills) marketplace instead.

## Repo structure

```
.claude-plugin/
  marketplace.json                  ← Claude Code marketplace catalog
.github/
  workflows/release-pr.yml          ← opens the release PR after a merge
  workflows/version-guard.yml       ← keeps hand edits out of `version`
  scripts/                          ← the shell behind both workflows
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
