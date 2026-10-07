---
name: solution-packages
description: >
  How to build a solution as a package file — a care pathway, or a program with its
  care pathways, with the flows, surveys, message templates and channels it needs — rather than only moving one
  that already exists. Covers asking the platform for the format instead of
  guessing it, the rules a schema cannot express, and what each kind arrives as
  once imported. Use this skill when the user wants to create or edit a solution
  package by hand, author a care pathway or flow as a file, or asks what belongs
  in a package JSON, or turn a clinical protocol, a spreadsheet or a conversation
  into a solution — the recipe here takes a document to a validated package in a
  staging organization, with `tabia validate` and `tabia render` in the loop. For
  moving an existing solution between environments, and for every `tabia` command
  used here, see the `tabia-cli` skill.
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

`--user-agent claude-code`, here and below, stands for the label of the agent driving the
CLI — `antigravity` under Antigravity. The `tabia-cli` skill's "Say what is driving the CLI"
section has the full list and the rule.

It answers with the shape generated from the classes that read the file, so it cannot
drift from what the import accepts. Laid out the way an OpenAPI document is:

- `formatVersion` — the format the rest of the document describes
- `file` — reference to the file's own root type
- `payloads` — reference to the payload type each kind carries, keyed by kind
- `components.schemas` — every type, flat and keyed by name

References inside it are `#/components/schemas/<name>` and resolve against the document
itself, so a payload can be followed to the types nested inside it.

It is structure without prose: no field carries a description, and a flow's actions, a
pathway's graph and its task specifications are free-form maps inside it. So read it for
names and types, and read a real export (below) for what goes inside those maps:

```bash
jq '.payloads' "$work/schema.json"                                   # kind -> its payload type
jq '.components.schemas.SurveyExportDTO.properties | keys' "$work/schema.json"
jq '[.components.schemas | to_entries[] | .key as $t | .value.properties // {} | to_entries[]
     | select(.value["x-whenAbsent"] == "ask") | "\($t).\(.key)"]' "$work/schema.json"   # asked for when left out
```

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
nobody asked for. A **program** is never dragged in either: a pathway's program stays a
placeholder unless the program is itself an item, and then the pathway belongs inside it. Flows, surveys, message templates, channels and funnels are the opposite: naming one
anywhere pulls it into the file. A funnel is pulled in only if it is published and has
a live step; any other stays a placeholder. An export whose every chosen item stays out is
refused rather than written empty.

The practical consequence when authoring: a flow your pathway starts belongs **in** the
file as an item; a program, a team or a medical code belongs as a placeholder.

### A program carries its care pathways inside it

A `PROGRAM` item's payload is the program (`program`: its name and archived flag) and, under
`pathways`, the care pathways it carries, each one the payload a pathway item has minus its own
`program`. Those pathways are not items of their own, so each carries a `ref` instead, and that is
the ref the rest of the file points at it by: a flow that creates a care plan in one of them names
it as `{"$$placeholder": true, "type": "Pathway", "ref": "<that ref>"}`, and the import relinks it
to the pathway it creates. Picking a program on the export screen, or with `tabia export
--program`, picks its pathways that are not archived along with it.

A pathway item on its own cannot land in a program of the same file: its `program` is read when
the pathway is created, before any item exists, so only the map can answer it. Put the pathway
inside the program instead. Pointing the program item at one the organization already has creates
neither the program nor its pathways, so what points at those pathways needs a mapping again.

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
only it refers to needs no mapping, though a survey, template or channel it dragged into the file
is still created as a copy. When authoring for an organization that already has content,
choose names that will not collide, so nobody has to make that choice on import.

Nothing constrains a pathway's, a program's or a survey's name.

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
| program | **a new program**, with the care pathways it carries created inside it as pathways arrive |

The message template's integration is asked for at import, because it decides what kind of
template is created. The channel's is not asked for and is left empty — an organization
receiving a solution often has no integration yet, and demanding one would block the import.

## What never travels

No patient data of any kind. No survey applications, flow instances or care plans. No media
file behind a template header — the binary stays where it was, and the template arrives
without it.

A package is configuration. If you think you are looking at a person in one, stop.

## From a protocol document to a validated package in staging

The whole authoring job, end to end. Every step until the import writes **nothing**, so
iterate as often as the file needs: `validate` and `render` cost one read-only request
and an offline read, and the target answers every problem at once. Do it in a
non-production organization meant for building — not the one a customer is shown — and
let the loop run as many rounds as it takes. The freedom ends at `--write`.

**0. Read the source for configuration, never for people.** A protocol, a spreadsheet or a
conversation describes what happens to *anyone* on the pathway. If it carries an example
patient, a real case, a phone number or a date of birth, none of that goes into the file —
a package is configuration, and a person in one is a defect. If the document itself is a
patient's record, stop and say so; it is not a source for a solution. The personal-data
rules of the `tabia-cli` skill apply to the source as much as to any API response.

**1. Sketch it before writing JSON, and have the user check the sketch.** Translate the
protocol into the platform's terms, as a short list:

- the **care pathway**: its events, their order and timing, the conditions between them;
- the **flows**: what is said to the patient, the answers that branch, where each branch goes;
- the **surveys**: the questions and their types;
- the **message templates** (what is sent outside a conversation) and the **channels**;
- what the **target supplies**: the program, the teams, the medical codes, an integration.

Ask the user — ideally the clinician who owns the protocol — whether that is what the
protocol says. A wrong interpretation caught here costs one message; caught after import, a
care pathway that speaks to patients. Choose names that will not collide in the target.

**2. Get the format and a scaffold** — the schema and a real export of something close, as
in [Never guess the format](#never-guess-the-format--ask-for-it) and
[Start from a real export](#start-from-a-real-export).

**3. Write the file** in the working directory, with readable refs (`triage-flow`,
`bp-survey`) and placeholders for everything in the last bullet above.

**4. Loop: validate, fix, render.**

```bash
tabia --user-agent claude-code validate "$work/solution.json" --profile staging/acme
tabia --user-agent claude-code render "$work/solution.json" --format markdown
```

Run it **without `--map`** while writing: there is no map yet, and none is needed for the
target to check the rest of the file. Once step 6 has run `resolve`, add
`--map "$work/map.json"` to every later round, so what is resolved stops being listed.

`validate` sends the file whatever the map holds — `import` would refuse while a reference is
unmapped — and splits the answer: **NEEDS A MAPPING** is the expected state of a draft, and
**IN THE FILE ITSELF** is the work. Its exit status says which: **0** the file has no errors
of its own, **1** fix what it lists, **2** the target could not be asked (say so; do not read
it as a pass). Fix every error at its `path` before the next round, as
[The dry run asks the target](#the-dry-run-asks-the-target) describes. `--json` gives the same
report for reading in a loop.

Then **read the diagram yourself**: every flow reachable from the pathway, every branch going
somewhere, every dashed node something the target can plausibly supply. `render` draws a
transition to a card the flow does not have as a *missing card* — the validator does not check
that, and neither does it check a survey question carrying an id from elsewhere (see
[the rule](#a-surveys-question-ids-must-be-absent)). Repeat until `validate` exits 0 and the
diagram matches the sketch.

**5. Show it.** Give the user the diagram — Mermaid renders in most places a conversation
goes, and `render --format html -o "$work/solution.html"` is a page to send to a clinician
(it fetches Mermaid from a CDN to draw; where that is blocked, send the Markdown instead) —
together with the NEEDS A MAPPING list and every warning. The diagram, not the JSON, is what a
clinician can check against the protocol.

**6. Resolve and confirm.** `tabia resolve` against the staging organization writes the map;
fill what it leaves with the user, never with an invented id, then `validate --map` until it
says *importable as is*. Then the [plan, resolve, import](#then-plan-resolve-import) sequence
below: the dry-run `import`, and `--write` to staging only once the user says so.

**7. Look at what arrived.** Flows land as drafts and templates await approval
([What each kind arrives as](#what-each-kind-arrives-as)). Publish in staging, run it with a
test contact, and only then think about production — by exporting **from staging**, so what
moves is the exercised configuration rather than the hand-written file, with the `tabia-cli`
skill's workflow.

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
edit. While the file is still a draft, `tabia validate` is the step between `plan` and
`resolve`: the same read-only request as the dry run, sent whatever the map holds, so the
target checks the rest of the file before anyone resolves a reference. `tabia render` draws
the file at any point, offline.

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
2. **The dry run is not optional**, and `validate` while writing does not replace it. Run
   `import` without `--write`, fix what its report lists until the package is importable,
   and show the user the final report, warnings included, before proposing the real one.
   See [The dry run asks the target](#the-dry-run-asks-the-target).
3. **Confirm with the user before any write.** Approval for one is not approval for the
   next.
4. **Never pass `--yes`.** It skips the production confirmation, which exists for this.
5. **Say what will arrive unpublished** — the flows, and any template awaiting approval —
   so nobody believes a solution is live when it is installed.
