# tabia-cli

A Claude Code skill for reaching a **deployed** Tabia environment — staging, production, a
particular organization — from the command line with the `tabia` CLI.

`tabia` is a standalone Python CLI that talks to the Tabia platform over HTTP, authenticated
with your personal access token. It can:

- **list and read** — `tabia ls pathway|flow|survey`, and `tabia api` as an escape hatch to any
  `/apiv1` endpoint;
- **move a solution between environments** — export a care pathway with its flows and surveys as
  one JSON package, `plan` it offline, `resolve` its external references against the target
  organization, then `import` it (dry run first, always);
- **manage profiles and tokens** — one profile per environment/organization pair, tokens held in
  the OS keyring.

## What the skill adds

The CLI's own `--help` covers the flags. This skill covers the parts that are easy to get wrong
and expensive when you do:

- **Personal data stays out of the transcript.** You may read a person's record through this CLI;
  Claude may not read it back. The skill routes such output to a file you own, or hands you the
  command for your own terminal, and explains the `--personal-data` gate — what a refusal does
  and does not mean, and why being asked is the ordinary case rather than a finding.
- **Production writes end with a person.** Nothing is sent without `--write`; a write to a
  `production/` profile asks a human to type the profile name, and the skill treats that prompt
  as the authorization rather than an obstacle — it prepares and dry-runs the whole transfer, then
  hands over one command for you to run.
- **The failure modes, named.** A disabled "Create token" button, a `403` that means narrow roles
  rather than a bad token, an `EOFError` that is the guard working, a `404` from an environment
  that predates the solution-package endpoints, a missing keyring.

## What it expects of you

- **Access to the CLI.** Its source repository is private, so the installer checks that the
  GitHub account you are signed in to `gh` with can read it. If you are a customer or partner and
  that check fails, ask your Tabia contact for access.
- **A personal access token** in the environment you are working with, minted in the web app
  under **Settings → Personal access tokens**. `OPERATIONAL_MANAGER` covers the whole
  pathway/flow/survey workflow.
- **Python 3.9+**, `gh`, and an OS keyring (Keychain on macOS, libsecret on Linux).

## Install the CLI

```bash
curl -fsSL https://static.tabia.health/install.sh | sh
```

Re-running it upgrades. `tabia --version` does not tell you whether your copy is current — ask
for the subcommand instead, e.g. `tabia api --help`.

## Use it

Once the marketplace is added and the plugin installed (see the [repo README](../../README.md)),
just say what you want in a deployed environment and Claude Code will pick the skill up:

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
