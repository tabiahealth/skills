---
name: tabia-cli
description: >
  How to reach a Tabia environment (staging, production, a particular
  organization) from the command line with the `tabia` CLI — list, export, plan,
  resolve and import care pathways, flows, surveys and funnels, and call any `/apiv1`
  endpoint with `tabia api`, learning its paths and payloads from the
  environment's own OpenAPI document. Use this skill when the user asks to
  inspect or change something in a deployed Tabia environment, to move a
  pathway, flow, survey or funnel between environments or organizations, or
  mentions `tabia`, `tabia auth`, profiles, personal access tokens (PAT),
  solution packages, or asks which endpoint does something or what it expects.
  Personal data is the user's to read, never Claude's: never use it to bring
  personal data into the conversation.
---

# Reaching Tabia environments with the `tabia` CLI

`tabia` is a standalone Python CLI that talks to a deployed Tabia platform over HTTP,
authenticated with the current user's **personal access token**. It moves care
pathways, flows, surveys and funnels between environments as a single JSON package, and reaches
any other endpoint through `tabia api`.

If it is not on this machine yet, **installing it is your first step** rather than
something to hand back to the user — see [Install and upgrade](#install-and-upgrade).

## Personal data

**The user may read personal data through this CLI. You may not.**

Someone allowed to see a person's record in the product is allowed to see it here — the
CLI authenticates as them, and the server enforces the same permissions either way — so
nothing in this section is a veto over their access, and it is not yours to second-guess.
What it does veto is the data arriving in *your* context. You can write the command, hand
it over, or put the rows in a file they own; you stop at reading them.

That asymmetry is the whole of it. The three rules below are how it gets applied.

**1. Prefer not to bring it to this machine at all.** A workstation is the worst place for
a copy of someone's record, so look for an answer that does not need one — reproduce
against a development environment that holds no real data, stay in the browser of an
environment that already holds it, or ask the person who owns it what they see, since a
symptom, a timestamp, an id shape and a stack trace are usually the whole debugging need
and none of them are PHI. Try those first and say which one you tried. If they genuinely
do not answer the question, fetching the real thing is on the table.

**2. Only when the user asks, and only after you have said what it will pull.** Never
reach for personal data on your own initiative — not to be thorough, not while debugging
something next to it. They ask in as many words; you name the endpoint, roughly how many
rows, and where the output will land; they say yes; then you run it — into a file, as rule
3 requires, not into view. Approval for one read is not approval for the next, and "I have
permission" answers a different question from "do you want this on your laptop".

**3. It does not pass through you.** This is the asymmetry in practice, and it is the rule
that holds when the other two have been satisfied. Writing a command or a script that
pulls personal data into a file the user owns is fine — *you* reading those rows is the
part that is not, because a row in this transcript sits in a store nobody approved for it
and cannot be taken back out. So send it to a file and leave it there:

- Redirect to a file outside the working tree (`mktemp -d`, or the session's scratchpad)
  — never to stdout in a tool call, and never through `--paginate` into the terminal.
- Do not read it back "just to check". Metadata is fine — an exit code, a file size, a
  `jq 'length'` that prints only a count. Content is not.
- When what the user needs is to *look* at the data, hand them the command for their own
  terminal. Their screen is an approved place for it; your context is not.
- `-q`/`jq` narrows volume, not sensitivity: one name is PHI as much as two hundred are.
  And delegating does not launder it — a subagent's output comes back here.

### `--personal-data`: the gate, and how to read it

**The platform names the endpoints that cannot return personal data, and this skill does
not restate that list.** An endpoint declared free of personal data promises its response
cannot contain data about an identifiable person; the environment publishes those at
`GET /apiv1/no-personal-data-endpoints`, and `tabia api` reads the list before each call,
letting a declared endpoint through and refusing everything else until `--personal-data`
says the caller knows the response may carry PHI or PII.

```
$ tabia api /patient/42
error: GET /patient/42 may answer with data about an identifiable person.
       This environment declares 50 of its 1553 endpoints free of personal data;
       this is not one of them. Pass --personal-data to say you know that.
```

That refusal is **the absence of a promise, not a finding**. The declared set is a small
minority of the API — the message prints the live count — and it is reference-data
catalogues: currencies, ICD, body parts, feature flags. So being asked is the ordinary
case, `/pathway`, `/chatflows`, `/survey` and `/me` included. A list that could not be
read declares nothing and leaves *every* call asking, which is the gate failing closed,
and the reason travels in the message. The flag itself restricts nothing: it is a claim,
not a control, and what it changes is that a call which may return a person's record
becomes something acknowledged rather than something done on the way to something else.

So the flag is a decision, not a retry. Most of this API is undeclared, so expect to pass
it for ordinary configuration reads — `/pathway`, `/survey`, `/me`. **That is not
permission to pass it for a patient endpoint.** The flag records that you knew; it does
not make the read acceptable, and nothing in the three rules above is softened by it. On
screen the two cases are indistinguishable, which is why the decision is yours to make
before you re-run rather than the CLI's to make for you:

- **Could the response describe an identifiable person, or are you unsure?** That is rule 2
  above — report the refusal, say what the call would return, and let the user ask before
  you re-run with the flag, into a file rather than into view.
- **Plainly configuration or reference data that is simply not annotated?** Pass the flag,
  saying in one line why you are satisfied it carries nobody. The response schema in the
  [environment's OpenAPI document](#finding-the-endpoint-ask-the-environment-not-your-memory)
  is the quickest way to be satisfied. An endpoint that genuinely cannot return personal
  data is missing its declaration, which is worth reporting to Tabia.
- **Everything refused?** Suspect the list, not the endpoint, and read the printed reason.

The cheapest double-check is to look before running. This call is **exempt from the gate**
— path templates, no person — so it works even where the list is missing:

```bash
tabia api /no-personal-data-endpoints -q '{declared, total}'
tabia api /no-personal-data-endpoints -q '.endpoints[] | select(.path | test("pathway"))'
```

Paths match per segment against the endpoint template, `{…}` standing for exactly one
segment, so `/currency/7` is `/currency/{id}` but `/currency/7/rate` is not. There is
deliberately no environment variable and no disk cache to reach for.

**If a command never asks, the installed copy predates the gate** — check for
`--personal-data` in `tabia api --help`, and re-run the installer rather than reading the
silence as approval. An older `tabia` gates nothing, which leaves the three rules above as
the only check.

The gate is on `api` alone, and that is enough: `ls`, `export`, `resolve` and `import`
reach almost nothing declared, gating them would put the flag on every invocation, and a
solution package deliberately carries **no** survey applications, flow instances or care
plans. When a pathway is what you need, `ls pathway` is both the narrower read and the
ungated one.

## The environments

| Environment | Host | Notes |
|---|---|---|
| Production | `https://app.tabia.health` | Live customer data. Several organizations share this host. |
| Staging | `https://staging.tabia.health` | Not a sandbox — it carries real-shaped data and is what customers are shown. |

The host does **not** identify the organization — several share one, which is why
profiles carry the org in their name. Every environment reachable with this CLI is fed by
real or real-derived data, so none of them earns a relaxation of the section above.

## When to reach for `tabia`

This CLI is for a **deployed** environment. Reach for it only when the user names one
(staging, production, a particular organization) or names a profile. "Test this", "check
whether it works", "reproduce the bug" mean whatever local or development setup the
project already has, unless the user says otherwise — **a configured profile is not
permission to use it.**

If the project has its own tooling for running locally, that tooling is the answer for
local work. Pointing `tabia` at `localhost` to shortcut it only adds a token and a
network hop.

## Install and upgrade

```bash
curl -fsSL https://static.tabia.health/install.sh | sh
```

**`tabia` not found** — `tabia: command not found`, `command not found: tabia`,
`tabia: not found`, whichever wording the shell uses — is a step, not a finding:
**install it and carry on.** Unlike `auth login`, this one is yours to run — with no
terminal to prompt at, it takes the defaults instead of blocking. Use the form below to
say so outright, since a bare `| sh` has no way to forward arguments to the script:

```bash
curl -fsSL https://static.tabia.health/install.sh | sh -s -- -y --dir ~/.local/bin
```

`-s --` is what hands `-y` and `--dir <path>` to the installer rather than to `sh`; reach
for it whenever nothing is there to answer a prompt. (That `-y` is the installer's own, and
has nothing to do with the CLI's `--yes` forbidden under [Writes](#writes-the-rules).)

It checks `curl` is present and that Python is 3.9+, then asks where to install and
defaults to `~/.local/bin/tabia`. A missing OS keyring only *warns* — the refusal comes
later, at first use. Re-running it upgrades.

**If you are not allowed to run it, hand it over.** A permission mode that refuses the
command, or a user who declines it, has settled the question — say so plainly, give them
the plain `curl … | sh` for their own terminal, and pick up once they say it is in. That
is a refusal to respect, not an obstacle to route around with another download path.

**A new machine needs two things, in that order**: the CLI, which is yours to install, and
a profile, which is not. So a missing `tabia` → install → `tabia auth list` → if that
comes back empty, hand over the `auth login` line and let them run it, since
[you cannot](#you-cannot-run-auth-login-yourself). Until a profile exists you cannot even
name the organizations the user can reach — that list comes from their token, so ask them
rather than guessing.

**Nothing about GitHub is needed to install.** The CLI is downloaded straight from
`static.tabia.health`, which carries whatever the source repository last published; that
repository stays private, but no account, sign-in or `gh` stands between a person and the
installer. What they still need from Tabia is a token in the environment itself.

**`tabia --version` cannot tell you whether a copy is current** — the version string has
not moved since the first release, so an installed copy from before a change still answers
`0.1.0`. To find out whether a subcommand exists on this machine, ask for it:
`tabia api --help`. If it is missing, re-run the installer instead of concluding the
feature does not exist.

A stale copy does not always fail. Two symptoms mean it is out of date even though it runs:

- **A message template or channel the package carries is listed twice**, under "will be
  created" and again under "needs resolving", and `import` refuses to send it as an
  unmapped reference. The copy predates the CLI knowing those kinds.
- **The dry run prints no validation report** on an environment that has the endpoint:
  only the banner and the item list, and no note that the environment cannot validate. The
  copy predates the dry run that asks the server, so a package it waves through has been
  checked by nobody. Whether the environment has the endpoint is one lookup in
  [its OpenAPI document](#finding-the-endpoint-ask-the-environment-not-your-memory):
  `jq '.paths | has("/solution-package/validate")' "$spec"`.

The remedy for both is to re-run the installer, not to work around the output.

## Profiles and authentication

A token is scoped to exactly one organization and cannot switch. One token, one
profile, per organization.

```bash
tabia auth login --profile staging/acme    --host https://staging.tabia.health
tabia auth login --profile production/acme --host https://app.tabia.health
tabia auth use staging/acme     # later commands act on this profile
tabia auth list                 # every profile, its org, and whether its token still works
tabia auth status               # who the active token is, and which roles it carries
tabia token list                # every token this user owns in this org (--json available)
```

`auth status` describes the token you are *using*; `tabia token list` describes the ones
the user *owns* in that organization — run it before suggesting they mint another, since
the one they need often already exists. Both return metadata, never the secrets.

**`token list` does not say which tokens are dead**: a revoked or expired one sits in that
table looking exactly like a live one. `--json` carries the flags the table drops, and is
also how you see the roles of a token other than the active one:

```bash
tabia token list --json | jq '[.[] | {id, name, revoked, expired, roles: [.roles[].value]}]'
```

Prefer that over `tabia api /personal-access-token/me`, which returns the same payload but
names the token's owner, so it is undeclared and asks for `--personal-data` first.

Name profiles `<environment>/<organization>`. Both halves matter: the same org exists in
several environments, and several orgs commonly share one host, so the URL alone never
tells you where a write lands. A `production/` prefix marks the profile as production on
its own — `auth login --production` does the same for a name that lacks it — and that mark
is what makes writes ask for confirmation, so **never create a production profile under a
name that hides it.**

Profile resolution order: `--profile` → `$TABIA_PROFILE` → whatever `auth use` selected.
With none of the three the command refuses rather than guessing.

The token is minted by the user in the web app under **Settings → Personal access
tokens**, with an expiry and narrow roles. `OPERATIONAL_MANAGER` covers the whole
pathway/flow/survey workflow. Do not tell the user to grant `ADMIN` just so `resolve`
can read `/terms` — that hands over everything beneath it for one lookup; `resolve`
reports what it could not read as **FORBIDDEN** and they fill those in by hand.

**Never ask the user to paste a token into the conversation, and never put one on a
command line.** `tabia auth login` prompts for it with hidden input, and stores it in
the OS keyring — Keychain on macOS, libsecret on Linux. If a token ever appears in
chat, in a file, or in shell history, say so and tell them to revoke it.

### When the "Create token" button is disabled

The button is disabled when `GET /personal-access-token/me/grantable-roles` comes back
empty, and **global roles do not count** — they are dropped before the role hierarchy is
expanded, since a token reaches one organization and `GLOBAL_ADMIN` must not seed `ADMIN`
in an organization its holder has no role in. So someone whose only access there is global
gets a disabled button however senior they are, and the tooltip is true even though it is
hard to believe.

The way out is an **active local role** — `OPERATIONAL_MANAGER` covers the whole CLI
workflow. Two traps: a role granted through the invitation flow is born `pending` and
counts for nothing until accepted, so "I already have the role" is usually a pending row;
and this is an access change, **so it is the user's to make, not yours** — never script
your way to granting anyone a role. One caveat when diagnosing: the page reads only the
response body, never the error, so a *failed* request renders identically to an empty
list — have the user check what that endpoint actually returned before you conclude
anything about roles.

Related, and the reason a working token can stop working: what a token carries is
recomputed per request as the intersection of its stored roles with the ones its owner
*still* holds. Losing the local role does not revoke the token, it empties it.

### You cannot run `auth login` yourself

**`tabia auth login` never works when an agent runs it.** The token is read with
`getpass`, and a tool call has no controlling terminal, so the prompt raises `EOFError`
before it can accept anything. There is no flag to add — the command is over before the
token is asked for. So do not run it: hand the user the exact line for **their own
terminal**, then confirm with `tabia auth list`, which you *can* run.

```bash
tabia auth login --profile staging/acme --host https://staging.tabia.health
```

`--token-stdin` is not the workaround it looks like: using it means the token passing
through you — a file you write, an env var you set, a message where they pasted it — which
is what the rule above forbids. It exists for the user's own scripting. `auth logout` is
not interactive, so it is fine either way — but it only forgets the credential locally:
the token still exists and still works until the user revokes it in the web app. The same
terminal-less reality returns on writes — see [Writes: the rules](#writes-the-rules).

## Say what is driving the CLI

Every call carries a `User-Agent` naming the tool — `tabia-cli/<version>` — which is how
our Datadog dashboards tell CLI traffic apart from the web application's at all.
`--user-agent` adds the name of whatever is driving the CLI, and that is what separates a
person working at their own terminal from an agent running the same command for them.

**Pass `--user-agent claude-code` on every `tabia` command you run yourself.**

```bash
tabia --user-agent claude-code ls pathway
tabia --user-agent claude-code api /currency
```

It goes before or after the subcommand, like `--profile`, and applies to every command.
The version prefix is never dropped, so all CLI traffic stays one group that can still be
split by caller: `--user-agent claude-code` sends `tabia-cli/0.1.0 (claude-code)`.

**A copy that rejects the flag predates it — re-run the installer rather than dropping
it.** Passing it after the subcommand fails legibly (`error: unrecognized arguments:
--user-agent claude-code`); passing it before, in the form above, does not — the parser
blames the positional instead and says `error: argument command: invalid choice:
'claude-code'`, which reads like a mistyped subcommand and is nothing of the kind. Both
exit 2, and neither means the label was wrong. `tabia --version` answers `0.1.0` either
way, as [ever](#install-and-upgrade); `tabia --help` lists the global options, so it
settles this one directly.

**A line you hand the user to run in their own terminal does not get the flag.** It says
who ran the command, so putting it on something a person will paste makes the record
wrong. That includes `auth login`, which you cannot run anyway.

`TABIA_USER_AGENT` sets the same label for a whole shell or a scheduled job, and an
explicit `--user-agent` beats it. A label is up to 40 characters of letters and digits
plus `.` `_` `-` `/`, starting with a letter or digit; anything else is refused rather
than sent.

This is attribution, not access: the flag changes nothing about what a token may reach,
and it is not a way to make a call look like it came from someone else.

## Reading an environment

```bash
tabia ls pathway --search diabetes      # also: flow, survey, funnel. --json for machine output
tabia api /currency                     # declared free of personal data: goes through
tabia api /me --personal-data           # not declared — most endpoints are not
tabia api '/pathway?size=5' --personal-data -q '.content[].name'
```

`tabia api` is the escape hatch for everything outside pathways, flows, surveys and funnels,
and [the environment's OpenAPI document](#finding-the-endpoint-ask-the-environment-not-your-memory)
is where its paths and bodies come from. The path is under `/apiv1`, the response body
goes to stdout (pretty JSON) and everything else to stderr, so `| jq` works unflagged.
`--paginate` walks this API's `page`/`last` paging and merges the `content` arrays, on a
`GET` only. A failing call prints the server's own response and exits non-zero.

`ls` is ungated and always fine — reach for it before `api` when it can answer the
question. Whatever `api` touches that the environment has not declared clean needs
`--personal-data`, which is most of the API and mostly says nothing about the call: read
[`--personal-data`](#--personal-data-the-gate-and-how-to-read-it) before adding it. Prefer
narrow reads over dumping whole collections either way — a deployed environment is not a
scratchpad.

### Finding the endpoint: ask the environment, not your memory

**Every environment describes its own API** at `GET /apiv1/openapi.json`, an OpenAPI
document generated from the code that environment runs. Any signed-in user can read it,
through a token too, and it is declared free of personal data, so it needs no
`--personal-data`. When the task is something `ls`, `export` and `import` do not cover,
this document is where the path, the method, the parameters and the body come from. Guessed
paths and payloads recalled from memory are not a source. Neither is a source checkout,
which may not match the version that environment is running.

It is about a megabyte, over a thousand paths. **Fetch it once into the work directory and
query the file**, rather than printing it or fetching it again for each question:

```bash
work=${work:-$(mktemp -d)}
spec="$work/openapi.json"
tabia --user-agent claude-code api /openapi.json > "$spec"

# which operations mention pathways — method, path, summary
jq -r '.paths | to_entries[] | .key as $path | .value | to_entries[]
       | "\(.key | ascii_upcase) \($path)  \(.value.summary // "")"' "$spec" | grep -i pathway

jq '.paths["/pathway"] | keys' "$spec"                                   # its methods
jq '.paths["/pathway"].get.parameters | map(.name)' "$spec"              # page/size → --paginate applies
jq '.paths["/pathway"].post.requestBody.content["application/json"].schema' "$spec"
jq '.components.schemas["<Name>"]' "$spec"                               # follow a $ref by hand
```

Its paths are relative to `/apiv1` (`servers` says so), which is the form `tabia api`
takes, so a path copied out of the document works as it is. A `$ref` reads
`#/components/schemas/<Name>` and resolves inside the same file. The file describes the API,
not anyone's data, and it goes in the same throwaway directory as everything else.

What the document is, and what it is not:

- **It is what this environment accepts.** Read it from the environment you are about to
  call. Staging and production can run different versions, so a document fetched from one
  says nothing reliable about the other.
- **Before a non-`GET` `tabia api`, read the operation's request body schema.** `import`
  has a dry run and `tabia api` does not: a `POST`, `PUT` or `DELETE` is sent the moment
  it runs. So checking the body against the schema is the only check before the call
  lands, and the confirmation under [Writes](#writes-the-rules) still applies after it.
- **It is not a permission list.** It lists operations whatever the token's roles, so a
  `403` on an operation it lists still means [roles too narrow](#troubleshooting).
- **It is not the personal-data list either.** `/no-personal-data-endpoints` alone decides
  the gate. The response schema is still the quickest evidence for the decision
  [`--personal-data`](#--personal-data-the-gate-and-how-to-read-it) asks of you. A response
  with a patient's name, a birth date, a contact or a `createdBy` user describes a person.
  A response that is only codes, labels and settings supports passing the flag, but proves
  nothing on its own.
- **Absent does not mean nonexistent.** The document leaves out global-admin and internal
  operations, which a token could not call anyway, and resources built for one particular
  customer. If the user names an endpoint that is not listed, it may still exist in their
  organization. Ask them rather than concluding it does not.
- **Name operations by method and path, never by `operationId`.** The ids are numbered
  automatically (`update_32`), and the numbers shift between releases.

If the call answers `404`, the environment predates the document. Say so, and fall back to
`ls` and the paths the user already knows.

## Moving a solution between environments

The middle three — `plan`, `resolve` and the dry-run `import` — are why the CLI beats the
import wizard:

```bash
tabia auth use staging/acme
work=$(mktemp -d)                                                   # 0. outside the repo

tabia ls pathway --search diabetes                                  # 1. find it
tabia export --pathway 42 -o "$work/diabetes.json"                  # 2. flows, surveys, funnels come along
tabia plan "$work/diabetes.json"                                    # 3. offline: creates vs needs
tabia resolve "$work/diabetes.json" --profile production/acme -o "$work/map.json"
tabia import "$work/diabetes.json" --map "$work/map.json" --profile production/acme          # dry run: validated, not written
tabia import "$work/diabetes.json" --map "$work/map.json" --profile production/acme --write
```

**Write packages outside the working tree** — `mktemp -d`, or the session's scratchpad.
Never `-o` into a repository: a package is a build artifact of one pair of environments,
worthless the moment either side changes, it is customer configuration rather than
something to paste into a PR, and a stray `diabetes.json` in `git status` is one
`git add .` from being committed. Delete the directory when the transfer is done; keeping
a package is the user's decision, not a default.

- `plan` is entirely offline. It splits the package into **will be created** and **needs
  resolving** (a program, a team, a medical code the package does not carry). References
  between items of the same package are never asked about.
- `resolve` matches those references by name against the **target** organization and
  writes `map.json` either way, exiting non-zero while anything is outstanding —
  **AMBIGUOUS**, **NOT FOUND**, **UNSUPPORTED** and **FORBIDDEN** are for a human to
  fill in, in the map file. Do not invent an id to make it pass.
- `import` refuses to send while any external reference is unmapped, and names each one.
- `import` without `--write` is the dry run, and it asks the target. It sends the package,
  the map and the renames to `POST /solution-package/validate`, which runs the checks the import runs
  before writing, writes nothing, and reports every problem at once: each with a `severity`,
  a `code`, the item's `ref` and a `path` into its payload. It exits non-zero while the
  package is not importable. A `WARNING` does not block the import but says something will
  not work, such as a flow step whose action the target does not know, so report every
  one. A clean report is not a guarantee: it does not check that the ids in the map exist,
  and it cannot see what only the write finds out. The `solution-packages` skill covers
  reading the report to fix a file.
- On an environment without that endpoint (`404`), the CLI says so and falls back to a
  dry run that is local only: banner and items, nothing sent, little proven. Say that to
  the user; `--write` is then the first time the server sees the package.
- `import` also asks the target which names it already holds, before anything is sent. A
  flow or a funnel is unique by name inside an organization, so the dry run lists each clash
  with the id of what holds the name, exits non-zero while any stands, and `--write` refuses.
  Per item, either create it under another name with `--rename <ref>="<new name>"`, or point
  the package at the one already there by adding a resolution for the item's own ref to the
  map file (`{"Flow": {"<ref>": {"reference": <existing id>, "display": "..."}}}`): nothing
  is created under it and the rest of the package is relinked to it. The dry run lists such
  items under "pointed at what the organization already has", and the write's summary lists
  them as reused. A name held by something nothing runs on — an archived or
  suspended item, one never published, or a funnel left with no live step — cannot be pointed
  at, so that one has to be renamed. An item pointed at the existing one is not created, so
  what only it refers to needs no mapping, but a survey, template or channel it dragged into
  the file is still created as a copy; say so when the user weighs the two. **The choice is the
  user's**: report
  what clashes and ask, never pick "point at the existing one" on your own, since a funnel
  with the same name and different steps fails when a patient reaches it rather than here.
  An environment that predates the check says so, and a taken name then fails the write itself.

Cross-profile is the normal case: the active profile is the source, the target is named
explicitly on `resolve` and `import`. Check you have them the right way round — an
import into the wrong organization is the failure mode this naming exists to prevent.

### What the package carries, and what it does not

Flows, surveys, message templates, message channels and funnels are carried: naming one
anywhere in the file pulls it in. `export` takes `--pathway`, `--flow` and `--funnel`, each
repeatable, so a funnel can also travel on its own. A *referenced* pathway is not — it stays a reference for the person
importing to resolve, so that packaging one care line never drags in a second.

A pathway flow node's `data.flow` is never placeholdered, so that flow is not discovered.
Credentials never travel: a template is asked which integration to use, and a channel
arrives with none. No patient data of any kind.

Funnels come with two limits worth saying before the write, not after it fails:

- Only a **published** funnel with a live step travels, which is why `tabia ls funnel` lists
  only published ones. A flow that names any other keeps it as an external reference to
  resolve: a `$$placeholder` in the file, which `plan` lists under NEEDS RESOLVING. When nothing
  chosen can travel, `export` is refused (`solution-package-export-no-items`) rather than
  written empty. A funnel that does
  travel arrives as an **unpublished draft**, and the flow cannot use it until it is
  published.
- A funnel whose name the target already uses is **refused before the write**, and the dry
  run says which. Rename it or point the package at the existing one, as described above,
  and let the user make that call.

To write a package rather than move one, see the `solution-packages` skill.

## Writes: the rules

1. **Nothing is written without `--write`.** The dry run is not silent: it sends a
   read-only validation request to the target, so it needs the right profile and a working
   token like any other call. Always run it first and show the user what it says,
   warnings included.
2. **Confirm with the user before any write** — `import --write` or a non-`GET`
   `tabia api`. Approval for one write is not approval for the next.
3. **Never pass `--yes`.** It skips the production confirmation, which is exactly the
   prompt a human should be answering. Expect to meet this as a failure rather than as a
   policy: a write to a `production/` profile asks for the profile name with `input()`,
   and with no terminal in a tool call it raises `EOFError` and aborts. **That is the
   guard working.** Nor is feeding the answer in a fix — `input()` reads happily from a
   pipe, so `echo production/acme | tabia import … --write` is exactly as forbidden, along
   with a heredoc, a `printf` or an expect script. The prompt is not an obstacle between
   you and the write; it *is* the write's authorization, and typing that name is a person
   saying "yes, that organization, in production".
4. Every write prints the org, host and acting user before sending. Read that banner back
   to the user rather than assuming the profile was the intended one.
5. The write is attributed to the token's owner — the person, not a service account. A
   flow published this way carries their name.
6. **There is no rollback.** An import runs in one transaction, so one that *fails* leaves
   nothing behind — but one that *succeeds into the wrong organization* has no undo, and
   cleaning up means deleting the items by hand where they should never have been. Which
   is why the profile check before the write matters more than any check after it.

### When a production write is actually needed

Do the whole job except the last step, then hand it over. That split is not a workaround
for the missing terminal: it puts the irreversible step with the person accountable for it.

1. **Prepare and verify everything** — `export`, `plan`, `resolve` and the dry-run
   `import`. All of that is yours to run, and it is where the real work is.
2. **Show the dry run**: the validation report, warnings included, and the
   org/host/acting-user banner it printed, so the user decides with the facts in front of
   them. Hand nothing over while the report says the package is not importable.
3. **Hand over one copy-pasteable command** for their own terminal — the same one, with
   `--write` and no `--yes`. Say that the CLI will ask them to type the profile name.
4. **Verify afterwards** with read-only commands and report what actually landed rather
   than assuming it worked.

## Troubleshooting

| Symptom | What it means |
|---|---|
| `tabia: command not found`, and its variants (`command not found: tabia`, `tabia: not found`) | The CLI is not installed here. Install it yourself — [Install and upgrade](#install-and-upgrade) — and only hand the command over if you are not allowed to run it. |
| `no profiles yet` | Nothing configured here. Give the user the `auth login` line to run themselves — you can neither run it nor mint the token for them. |
| `no profile selected` | Profiles exist but none is active. Name one with `--profile`, or `tabia auth use <name>`; the CLI refuses rather than guessing. |
| The "Create token" button is disabled | They hold no grantable role in that organization; global roles do not count. See [When the "Create token" button is disabled](#when-the-create-token-button-is-disabled). |
| `EOFError` from `auth login`, or at a production confirmation | No terminal in a tool call. The first is expected and the user runs the command themselves; the second is the guard working — report the abort, never retry with `--yes`. |
| `… may answer with data about an identifiable person` | The endpoint is not in this environment's declared-clean set — the ordinary case, not a finding. Decide before adding `--personal-data`; if the response would describe a person, rule 2 applies and the user asks. See [`--personal-data`](#--personal-data-the-gate-and-how-to-read-it). |
| `cannot tell whether … answers with personal data` | The declared list could not be read, for the reason printed with it, so *every* call asks. Check with `tabia api /no-personal-data-endpoints`, which is exempt from the gate. |
| `403` from `auth status` | Unknown, tampered, revoked, expired or demoted token — the auth filter answers the same for all five, deliberately, so the status call cannot tell you which. Check in the web app whether the token is still listed and whether its owner still holds the local role; the fix either way is a fresh token the user mints and logs in with. |
| `403` on a specific endpoint, e.g. `ls pathway` | Usually not the token being rejected but its **roles being too narrow** — a `SPECIALIST` token 403s on `/pathway`, `/chatflows` and `/survey` alike. `auth status` shows what it carries; the fix is a new token with `OPERATIONAL_MANAGER`, since a token's roles cannot be edited. |
| `auth list` shows an error in a profile's NOTE column | That token is dead; the others are fine. `production` on its own is not an error — a production profile always carries it. |
| `404` from `tabia api /openapi.json` | The environment predates its published OpenAPI document. Everything else still works. Fall back to `ls` and the paths the user knows, and do not guess the rest. |
| `404 on POST /solution-package/export` (or the same on import) | The environment predates the solution-package endpoints — the CLI says so by name. `auth`, `ls`, `api` and the offline `plan` still work; the transfer does not. |
| The dry run notes that the environment cannot validate | The target predates `/solution-package/validate`, and the dry run fell back to local only: nothing was sent and little is proven. Say so; `--write` is the first time the server sees the package. |
| The dry run prints no validation report and no such note, or `plan` lists a template or channel both as created and as needing resolving | A stale installed copy. Re-run the installer; see [Install and upgrade](#install-and-upgrade). |
| A subcommand or flag is not recognised | Likely an old installed copy — re-run the installer (see above); do not trust `--version`. |
| `secret-tool is installed, but no keyring is answering it` | `secret-tool` is there but no keyring daemon runs on the D-Bus session bus, as after installing `libsecret-tools` alone on WSL. The CLI's error message prints the two commands that start a bus and a keyring; they are the user's to run, not yours. |
| No keyring (headless box, container) | The CLI refuses rather than writing the token in the clear. `TABIA_ALLOW_PLAINTEXT_TOKENS=1` opts into a `600` file — only suggest it with the trade-off stated. The CLI creates that file itself, so do not tell anyone to create it, and the variable has to be set on every command, not only on `auth login`. |

Profiles live in `~/.config/tabia/profiles.json` (no credentials, safe to read). Renaming
a profile by hand orphans its keyring entry — log in under the new name, then
`auth logout` the old one.
