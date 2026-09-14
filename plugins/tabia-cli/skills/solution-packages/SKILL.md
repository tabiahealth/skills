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

## Never guess the format — ask for it

```bash
tabia api solution-package/schema > "$work/schema.json"
```

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

## Start from a real export

Reading the schema tells you what is allowed. An export tells you what a working example
looks like, which is faster and gets the conventions right for free:

```bash
tabia export --pathway 42 -o "$work/scaffold.json"
```

Edit that. For a solution with no ancestor, export the closest thing that exists and
replace its contents — the skeleton is worth more than the specific pathway.

Write packages **outside any repository**, in `mktemp -d` or the session scratchpad.

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
nobody asked for. Flows, surveys, message templates and channels are the opposite: naming
one anywhere pulls it into the file.

The practical consequence when authoring: a flow your pathway starts belongs **in** the
file as an item; a program, a team or a medical code belongs as a placeholder.

### Dependencies may be circular

A flow applies a survey whose completion starts a flow back; a channel cites a flow that
cites the channel. That is fine and needs no ordering — the import creates everything
before relinking anything. Do not try to sort the items.

### A flow's name is unique per organization

Two flows cannot share a name in one organization, and the check is case-insensitive and
counts archived ones. Importing a file whose flow name is already taken fails the **whole**
package. The import can rename an item on the way in, and the interface asks before
submitting. When authoring for an organization that already has content, choose names that
will not collide.

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
tabia plan "$work/solution.json"                                     # offline: creates vs needs
tabia resolve "$work/solution.json" --profile staging/acme -o "$work/map.json"
tabia import "$work/solution.json" --map "$work/map.json" --profile staging/acme
tabia import "$work/solution.json" --map "$work/map.json" --profile staging/acme --write
```

`plan` is offline and is the cheapest check on a hand-written file: it reads the items,
subtracts the refs the file satisfies itself, and lists what is left. Run it after every
edit.

## Guardrails

Authoring is riskier than moving, not safer. When a package moves between environments,
something in it was already exercised somewhere. A file written from scratch has been
exercised nowhere, and a care pathway drives automation that speaks to patients.

1. **Import to a non-production environment first, and look at the result.** A solution
   that parses is not a solution that behaves.
2. **The dry run is not optional.** Run `import` without `--write` and show the user what
   it says before proposing the real one.
3. **Confirm with the user before any write.** Approval for one is not approval for the
   next.
4. **Never pass `--yes`.** It skips the production confirmation, which exists for this.
5. **Say what will arrive unpublished** — the flows, and any template awaiting approval —
   so nobody believes a solution is live when it is installed.
