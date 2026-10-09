# tabia-cli

Agent skills, for Claude Code and Antigravity, for reaching a **deployed** Tabia
environment — staging, production, a particular organization — from the command line with the
`tabia` CLI.

`tabia` is a standalone Python CLI that talks to the Tabia platform over HTTP, authenticated
with your personal access token. It can:

- **list and read** — `tabia ls pathway|flow|survey|funnel|program`, and `tabia api` as an escape hatch to any
  `/apiv1` endpoint;
- **move a solution between environments** — export a care pathway, or a program with its care pathways, with their flows, surveys and funnels as
  one JSON package, `plan` it offline, `resolve` its external references against the target
  organization, then `import` it (dry run first, always: the target validates the package
  and reports every problem, without writing anything);
- **write and explain a solution** — `validate` a package still being written against a staging
  organization without waiting for every reference to be resolved, and `render` any package as a
  diagram (Mermaid, Markdown or an HTML page) of its pathways, flows and what they refer to;
- **manage profiles and tokens** — one profile per environment/organization pair, tokens held in
  the OS keyring.

## What the skill adds

The CLI's own `--help` covers the flags. This skill covers the parts that are easy to get wrong
and expensive when you do:

- **Personal data stays out of the transcript.** You may read a person's record through this CLI;
  the agent may not read it back. The skill routes such output to a file you own, or hands you the
  command for your own terminal, and explains the `--personal-data` gate — what a refusal does
  and does not mean, and why being asked is the ordinary case rather than a finding.
- **The API comes from the environment.** Each environment serves an OpenAPI document of its own
  API. The skill fetches it once, queries it with `jq` for the path, parameters and body it
  needs, and reads the request schema before any write through `tabia api`. It does not guess
  endpoints from memory.
- **Production writes end with a person.** Nothing is written without `--write` (the dry run
  sends only a read-only validation request, and the skill fixes what it reports); a write to a
  `production/` profile asks a human to type the profile name, and the skill treats that prompt
  as the authorization rather than an obstacle — it prepares and dry-runs the whole transfer, then
  hands over one command for you to run.
- **The failure modes, named.** A disabled "Create token" button, a `403` that means narrow roles
  rather than a bad token, an `EOFError` that is the guard working, a `404` from an environment
  that predates the solution-package endpoints, a missing keyring.

## What it expects of you

- **A personal access token** in the environment you are working with, minted in the web app
  under **Settings → Personal access tokens**. `OPERATIONAL_MANAGER` covers the whole
  pathway/flow/survey workflow.
- **Python 3.9+**, `curl`, and an OS keyring (Keychain on macOS, libsecret on Linux).

## Install the CLI

```bash
curl -fsSL https://static.tabia.health/install.sh | sh
```

Re-running it upgrades. `tabia --version` does not tell you whether your copy is current — ask
for the subcommand instead, e.g. `tabia api --help`. A dry run `import` that prints no
validation report, and no note that the environment cannot validate, is the usual sign of a
stale copy.

## Use it

Once the plugin is installed — in Claude Code through the marketplace (see the
[repo README](../../README.md)), or in Antigravity as below — just say what you
want in a deployed environment and the agent will pick the skill up:

> "List the diabetes pathways in staging for acme"
>
> "Move pathway 42 from staging/acme to production/acme"
>
> "Write me a package for a hypertension care line with its reminder flow"

Two skills ship here:

- [`tabia-cli`](skills/tabia-cli/SKILL.md) — the full workflow, the personal-data rules and the
  troubleshooting table.
- [`solution-packages`](skills/solution-packages/SKILL.md) — writing a package file rather than
  only moving one: asking the platform for the format, the rules a schema cannot express, and what
  each kind arrives as once imported.

## Antigravity

Install the plugin straight from this repository with the `agy` CLI:

```bash
agy plugin install https://github.com/tabiahealth/skills
```

Run it again to update. For workspace-only installs, see the
[repo README](../../README.md#antigravity).

## Any agent

The guardrails above apply to any agent that runs these skills, not only to Claude Code. What
changes is the label the agent puts on its CLI traffic — `claude-code` or `antigravity` — so
that each agent's calls can be told apart.
