---
name: solution-packages
description: >
  How to build a solution as a package file — a care pathway with the flows,
  surveys, message templates and channels it needs — rather than only moving one
  that already exists. Covers asking the platform for the format instead of
  guessing it, the rules a schema cannot express, and what each kind arrives as
  once imported. Use this skill when the user wants to create or edit a solution
  package by hand, author a care pathway or flow as a file, or asks what belongs
  in a package JSON. For moving an existing solution between environments, and
  for every `tabia` command used here, see the `tabia-cli` skill.
---

# Writing a solution package

A solution package is one JSON file carrying a whole solution: care pathways, the flows
they reach, the surveys those flows apply, the message templates they send and the
channels they speak on. The `tabia-cli` skill covers moving one between environments.
This one covers **writing one** — which is the same file, and a different job.

It is a supported way to build: the format is a documented contract, and the import is
the same code path either way. A package written by hand is how a solution gets composed
once and installed in many organizations.

## Somewhere to work

Everything below writes files. Put them in a temporary directory outside any repository —
a package is configuration for one pair of environments, worthless once either side
changes, and a stray `solution.json` in `git status` is one `git add .` from being
committed:

```bash
work=$(mktemp -d)        # or the session scratchpad; anywhere but the working tree
```

Delete it when the job is done. Keeping a package is the user's decision, not a default.

## Never guess the format — ask for it

```bash
tabia --user-agent claude-code api solution-package/schema > "$work/schema.json"
```

`tabia api` takes a path under `/apiv1`, so that is a `GET` of
`/apiv1/solution-package/schema`.

It answers with the shape generated from the classes that read the file, so it cannot
drift from what the import accepts. Laid out the way an OpenAPI document is:

- `formatVersion` — the format the rest of the document describes
- `file` — reference to the file's own root type
- `payloads` — reference to the payload type each kind carries, keyed by kind
- `components.schemas` — every type, flat and keyed by name

References inside it are `#/components/schemas/<name>` and resolve against the document
itself, so a payload can be followed to the types nested inside it.

**Do not paste field lists into a conversation from memory, and do not trust an older
answer.** The kinds a package carries have grown more than once. The schema is the only
statement of the shape that is current by construction.

The environment also publishes an OpenAPI document of its whole API at
`/apiv1/openapi.json`, and the `tabia-cli` skill covers fetching and querying it. **For the file itself, the package
schema is the authority**, because it is generated from the code that reads packages. The
OpenAPI document covers what surrounds the package: the operation that publishes a flow that
arrived as a draft, or the endpoints that answer what a placeholder should point at. Each
call you find there is still a `tabia api` call, with the same personal-data gate and the
same confirmation before a write.

## Start from a real export

Reading the schema tells you what is allowed. An export tells you what a working example
looks like, which is faster and gets the conventions right for free:

```bash
tabia --user-agent claude-code export --pathway 42 -o "$work/scaffold.json"
```

Edit that. For a solution with no ancestor, export the closest thing that exists and
replace its contents — the skeleton is worth more than the specific pathway.

Write it into the working directory from the start of this skill, never into a repository.

## The rules a schema cannot express

These are what make a file work rather than merely parse. None of them is a field.

### An item's `ref` is how the file points at itself

Every item has a `ref`. Every reference to that entity elsewhere in the file carries the
**same** `ref`, and that is the entire linking mechanism — the import builds `ref → new
id` in a first pass and relinks in a second.

The refs an export writes are derived from the source entity, but **a hand-written file
does not have to reproduce them**. Any string works as long as it is used consistently:
the item that declares `"ref": "triage-flow"` is found by every placeholder that says
`"ref": "triage-flow"`. Pick something readable. Consistency is the whole requirement.

Two items must never share a ref. The last one written would silently win.

### `$$placeholder` marks what the file does not carry

A reference to something that must already exist in the target organization is written as
a placeholder rather than an id:

```json
{ "$$placeholder": true, "type": "Program", "ref": "program-chronic", "suggestion": "Chronic care" }
```

`suggestion` is a human label to match against; it is not authoritative. The person
importing points each placeholder at something real. `tabia plan` lists them offline, and
`tabia resolve` matches them by name against the target.

### Being referenced pulls some kinds in and not others

A **care pathway** is never dragged in by being referenced — one pathway mentioning
another leaves a placeholder, because packaging it would drag in a second care line
nobody asked for. Flows, surveys, message templates, channels and funnels are the opposite: naming one
anywhere pulls it into the file. A funnel is pulled in only if it is published and has
a live step; any other stays a placeholder. An export whose every chosen item stays out is
refused rather than written empty.

The practical consequence when authoring: a flow your pathway starts belongs **in** the
file as an item; a program, a team or a medical code belongs as a placeholder.

### Dependencies may be circular

A flow applies a survey whose completion starts a flow back; a channel cites a flow that
cites the channel. That is fine and needs no ordering — the import creates everything
before relinking anything. Do not try to sort the items.

### A flow's name is unique per organization

Two flows cannot share a name in one organization, and the check is case-insensitive and
counts archived ones. A funnel's name is unique per organization too, on the same terms.
Importing a file whose flow or funnel name is already taken fails the **whole** package, so
both the wizard and the CLI check the names first and offer, per item, to create it under
another name or to point the package at the one the organization already has (nothing is
created under it, and the rest of the package is relinked to it). A name held by something
nothing runs on — an archived or suspended item, one never published, or a funnel left with no
live step — can only be renamed. An item pointed at the existing one is not created, so what
only it refers to needs no mapping. When authoring for an organization that already has content,
choose names that will not collide, so nobody has to make that choice on import.

Nothing constrains a pathway's or a survey's name.

### A survey's question ids must be absent

Question and choice ids are handles on rows of the organization they came from. Leave them
out; the publisher refuses a draft carrying an id that matches none of its own rows.

## What each kind arrives as

Importing is not publishing. Say this to the user rather than letting them discover it:

| kind | arrives |
|---|---|
| care pathway | as exported |
| flow | **a draft** — publish each one before a pathway can start it |
| survey | live only if it was live where it came from |
| message template | **pending approval** by the messaging provider; a flow that sends it fails until approved |
| message channel | **without its integration**, so it carries no credential and sends nothing until one is attached |
| funnel | **an unpublished draft** — publish it before a flow can start it or conclude a step of it |

The message template's integration is asked for at import, because it decides what kind of
template is created. The channel's is not asked for and is left empty — an organization
receiving a solution often has no integration yet, and demanding one would block the import.

## What never travels

No patient data of any kind. No survey applications, flow instances or care plans. No media
file behind a template header — the binary stays where it was, and the template arrives
without it.

A package is configuration. If you think you are looking at a person in one, stop.

## Then: plan, resolve, import

Once the file is written, the sequence is the `tabia-cli` skill's, unchanged:

```bash
tabia --user-agent claude-code plan "$work/solution.json"            # offline: creates vs needs
tabia --user-agent claude-code resolve "$work/solution.json" --profile staging/acme -o "$work/map.json"
tabia --user-agent claude-code import "$work/solution.json" --map "$work/map.json" --profile staging/acme          # dry run: validated, not written
tabia --user-agent claude-code import "$work/solution.json" --map "$work/map.json" --profile staging/acme --write
```

`plan` is offline and is the cheapest check on a hand-written file: it reads the items,
subtracts the refs the file satisfies itself, and lists what is left. Run it after every
edit.

### The dry run asks the target

`plan` only knows the file. The dry run, `import` without `--write`, is the check that asks
the environment: it sends the package and the map to `POST /solution-package/validate`,
which runs the same validation the import runs before writing, writes nothing, and answers
with **every** problem it found rather than the first. It exits non-zero while the package
is not importable.

Because the import refuses on those same checks, a package the dry run accepts will not be
refused for anything the validator looks at. That is a narrower promise than it sounds. The
validator does not check that an id in the map exists in the organization (the template's
integration aside), and it cannot see what only the write finds out, such as a database
constraint. A clean report is necessary, not sufficient, which is why guardrail 1 still
asks for a non-production import and a look at the result.

The report is `importable` plus a list of issues. The fields that matter for fixing a file:

- `severity`: `ERROR` blocks the import, `WARNING` does not.
- `code`: a stable name for the problem, and the one the import refuses with. Reason about
  the code rather than the wording, which can change.
- `ref` and `index`: the item, by the ref you gave it and by its position in the file. The
  position is how you find it when the ref itself is the problem, missing or shared.
- `path`: a JSON pointer into **that item's payload**, not into the whole file. Open the
  item first, then follow the pointer inside its payload.
- `message`: English, for a person. It says what is wrong; `details` carries the values
  involved, such as the name that is taken.

So the loop is: fix the file at each `path`, run `plan` again, and re-run the dry run until
`importable` is true. Fix everything one report lists before re-running; it lists them all
so that one round can cover them. Do not edit a placeholder into an invented id to make an
error go away; an unanswered placeholder is for the map, and the map is for a person.

**A `WARNING` is not a blocker, and that is why it has to be said out loud.** A
`flow-import-unknown-action` means a flow uses an action this environment does not know:
the flow imports, and that step will not run. In automation that speaks to patients, a step
that silently does nothing is a behaviour change nobody chose. Name every warning to the
user with the item it points at, and let them decide whether that is acceptable.

When `importable` is true, show the user the **final report, warnings included**, before
proposing `--write`. If a write is refused anyway, the refusal carries the first error's
code and the whole report under `content.issues`; read it the same way.

**On an environment that predates the endpoint (`404`)**, the CLI says so and falls back to
the old dry run, which is local only: it prints the banner and the items, sends nothing,
and proves little beyond the file being readable. Tell the user that in as many words. The
server then sees the package for the first time on `--write`, which makes the non-production
import the only real check. A dry run that prints neither a report nor that note comes from
an installed copy that predates the change; the `tabia-cli` skill's install section covers
it.

## Guardrails

Authoring is riskier than moving, not safer. When a package moves between environments,
something in it was already exercised somewhere. A file written from scratch has been
exercised nowhere, and a care pathway drives automation that speaks to patients.

1. **Import to a non-production environment first, and look at the result.** A solution
   that parses is not a solution that behaves.
2. **The dry run is not optional.** Run `import` without `--write`, fix what its report
   lists until the package is importable, and show the user the final report, warnings
   included, before proposing the real one. See
   [The dry run asks the target](#the-dry-run-asks-the-target).
3. **Confirm with the user before any write.** Approval for one is not approval for the
   next.
4. **Never pass `--yes`.** It skips the production confirmation, which exists for this.
5. **Say what will arrive unpublished** — the flows, and any template awaiting approval —
   so nobody believes a solution is live when it is installed.
