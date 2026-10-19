---
name: refinement
description: Use when a Jira issue — a Story, Bug, or Task — must be broken down into implementation sub-tasks. Requires, before it runs: the Atlassian MCP connection and, for a Story, the `ready_for_refinement` label (a Bug or Task needs no label). Because this is a git superrepo, the skill then **checks only** that each `--repo` submodule's knowledge graph (`.ua/`) is at the repo's current `HEAD` — it does **not** update, rebuild, or run `/understand` in any form. If any repo's graph is stale, the run stops and writes nothing. Reads the issue and its linked Confluence pages from Jira, splits the work per component (BE / FE / QC) and per business capability, then writes self-contained sub-task markdown files under `docs/refinement/` whose descriptions stay in plain language (no class, method or file names) for the developer to review. It always re-analyses the issue and writes fresh files, even when the issue already carries sub-tasks on Jira. Read-only against Jira: this skill never creates or moves tickets, and never runs `/refinement:create`. Run as `/refinement ACC-8686 --repo accountia-backend`; creating the reviewed sub-tasks on Jira is a separate, developer-run step.
---

# Refinement

Turn one Jira **issue** — a Story, Bug, or Task — into a reviewed set of self-contained sub-task files under `docs/refinement/`. The sub-tasks are the deliverable.

This skill reads Jira and never writes to it. It treats the repos' knowledge graphs (`.ua/`) as the ground truth for what code exists, splits and defines the sub-tasks, and stops at a review gate.

**Every `--repo` graph must be current before anything else happens.** The skill checks only — it does **not** update, rebuild, or run `/understand` in any form. It does not read the issue in depth, split the work, or write a single file until **every** graph is confirmed at its repo's current `HEAD` — and if one is stale, the run stops there and writes nothing rather than producing a breakdown that is only partly grounded.

**This skill always produces files.** It re-analyses the issue and writes the sub-task files from scratch every time it runs — the presence of existing sub-tasks on the issue never stops it and never changes what it does. Existing sub-tasks are context to read, not a reason to skip the work, and not a source to copy from. A refinement can outlive the tickets it once produced: the graph has moved, a requirement was clarified, or the earlier breakdown was simply wrong. Report what already exists on the issue, then write the files anyway, and let the developer reconcile the two.

The skill is also **self-contained**: it does not invoke `/refinement:create` or any other skill, and it does not depend on any skill being present.

## Input

```
/refinement <ISSUE-KEY-or-URL> --repo <repo>[,<repo>...]
```

- `<ISSUE-KEY-or-URL>` — e.g. `ACC-8686` or `https://genieitsoultions.atlassian.net/browse/ACC-8686`. The skill is written for **Story**, **Bug** and **Task** issues; fetch the `issuetype` and flag it if it is an Epic or any other type.
- `--repo` — required, never guessed. One or more accountia repos to ground on (`accountia-backend`, `accountia-frontend`, `location-service`, the superrepo itself, ...). Comma-separated or repeated.

The issue may already have sub-tasks on Jira, and usually will if it has been refined before. That is expected and is **not** a reason to stop: read them as evidence of what was decided last time, report them, and produce a fresh breakdown from the issue and the graph. Where the new files disagree with an existing sub-task, say so in `00-README.md` — the developer decides which wins.

## Hard rules

These are not negotiable, even under pressure to move fast:

1. **Never write to Jira.** No transitions, no edits, no comments, no issue/Epic/subtask creation, no status changes, no assignment. This skill only *reads* Jira.
2. **Never invoke `start-ticket`** — it is another team's skill and touches Jira state. Do not call it, do not copy its behaviors.
3. **Never run `writing-plans` and never create plan documents.** Sub-task files are self-contained; there is no plan layer and no plan links.
4. **Never invoke `/refinement:create`, and never create Jira tickets from the sub-task files.** The skill ends at the review gate. Ticket creation is a separate step the developer runs later, in a separate skill, at a time of their choosing. Never chain into it, never suggest in your own output that it will happen automatically, and never do it because the folder looks finished.
5. **Never invoke any other skill from this one.** This skill is self-contained: it must work whether or not any other skill in the family exists.
6. **Always produce the files, even when the issue already has sub-tasks.** Existing sub-tasks are context to read and report, never a reason to stop, and never a source to copy from. Produce a fresh breakdown from the issue and the graph every time.
7. **Never guess the repo** — `--repo` must be explicit, else ask.
8. **Never edit the issue description.**
9. **Never generate sub-task files before the issue spec AND the relevant `.ua/` graph have both been read.**
10. **Never run past a failed hard gate, never refine against a stale graph, and never update the graph.** Gates 1–4 stop the skill. For each `--repo`, dispatch a **parallel sub-agent** to check that its `.ua/meta.json` `gitCommitHash` equals the repo's `HEAD` — **read-only, no `/understand`**. All repos are checked concurrently. The run does not go on to reading the issue in depth, fetching Confluence pages, splitting the work, or writing any file until **every** `--repo` graph is confirmed at its repo's `HEAD`. If any graph is stale, the run stops there: report the blocker and write nothing. **Never** run `/understand` — not incremental, not full, not with `--full`, not in any form. Updating the graph is the developer's job (via `/refinement-sync`), not this skill's. Reading the source by hand is **not** a substitute for the graph.

## Red flags — stop and start over

- "I'll just create the tasks on Jira now, it's faster"
- "The issue doesn't say which repo, I'll assume backend"
- "I'll skip the review gate, the developer is busy"
- "I'll run `start-ticket` to get the spec sorted first"
- "I'll run `/refinement:create` since the files are ready anyway"
- "The folder is approved — creating the tickets is the obvious next step"
- "`/refinement:create` is only one more call, it saves the developer a step"
- "The issue already has sub-tasks, so the work is done"
- "Sub-tasks already exist on Jira, I'll just report that and stop"
- "The existing sub-tasks look right, I'll skip writing the files"
- "I'll update the existing sub-tasks to match instead of writing fresh files"
- "I'll reuse the existing sub-task descriptions rather than re-analysing"
- "Writing fresh files would create duplicates, so I'll stop instead"
- "I'll write a plan document too, it helps"
- "I'll draft sub-tasks — I'll read the graph later"
- "One sub-task covering both backend and frontend is simpler"
- "I'll skip the QC task, the developer can test it themselves"
- "It's a bug, not a story, so this skill doesn't apply"
- "It's only a Task, so I'll skip the QC task"
- "The graph is probably fine, I'll skip the freshness check"
- "The graph is only two commits behind, close enough to refine against"
- "One repo's graph is current, so I'll go ahead with both"
- "The graph is stale, but I'll run `/understand` to update it quickly"
- "I'll run `/understand --full` to fix the stale graph and then continue"
- "I'll run `/understand --repo <repo>` without `--full` to update the graph"
- "`/understand`'s validation is just being fussy; I'll carry on and note it in the README"
- "I'll write the files now and flag the stale graph for the developer to sort out later"
- "The tool is broken, so the graph gate doesn't apply this time"
- "I'll skip the comments, the description is clear enough"
- "The comments are just discussion, the description is what matters"
- "I can't reach Jira, but I'll work from the branch name"
- "The graph is stale but I'll be careful about the line numbers"
- "There's no `ready_for_refinement` label on this Story, but the description looks clear enough"
- "There's no `ready_for_refinement` label on this Story, but the sub-tasks already exist so it must be refined"
- "It's basically a bug, so I'll skip the label check on this Story"
- "I probably can't create sub-tasks, so I can't do the refinement either"
- "The label is `ready-for-refinement`, that's close enough (on a Story)"
- "I'm on a feature branch, but the code is nearly the same"
- "The plan says FULL_UPDATE, I'll force incremental instead to save time"
- "The graph only covers half the repo, I'll force incremental instead"
- "I'll pass --full to skip `/understand`'s own check"
- "I'll pass --full on the first run, it's more reliable than incremental"
- "The incremental update failed, so the graph can't be updated — I'll stop without trying the full rebuild"
- "The incremental path errored, but I'll run the same incremental path again"
- "I'll escalate to --full even though the incremental run succeeded"
- "The hashes match, but I'll run `/understand` anyway just in case"
- "I'll hand-edit meta.json so the hash matches"
- "I'll use the graph from another repo, it's similar"
- "I'll rebase/reset the submodule to get it onto the default branch"
- "I'll overwrite the uncommitted changes in the submodule, they're probably junk"
- "I'll say the API accepts the new field — the implementer can work out whether that's a new endpoint"
- "Extending is the obvious choice, I don't need to check what the graph says the operation does today"
- "The open question is in the README, that's enough"
- "The template is a guide, I'll structure the file my own way"
- "The prose explanation is fine, the developer can work out what to do from it"
- "The form that collects the value and the screen that shows it are on different screens, so they're two sub-tasks"
- "I'll split the backend into a task that stores the field and a task that returns it — each is independently shippable"

All of these mean: reread the Hard Rules. The deliverable is reviewed sub-task files, nothing more.

## Preflight — required, runs before any other step

Two kinds of check, and **both stop the run when they fail**:

- **Gates 1–3 depend on Jira** — nothing local can fix them. If one fails, report it and stop.
- **Gate 4 is yours to perform.** This project is a **git superrepo** — each `--repo` is a submodule. Dispatch **parallel sub-agents** — one per repo — to check that each repo's `.ua/meta.json` `gitCommitHash` equals its `HEAD`. All repos are checked concurrently. **Read-only — never run `/understand`.** The run does **not** continue to the issue, the split, or any file until **every** `--repo` graph is confirmed at its repo's `HEAD`. If a graph is stale, that is a stop, not a caveat: report it and end the run.

A sub-task breakdown built on stale code is worse than no breakdown, because it looks authoritative and is not. A breakdown built on a graph that is only *half* checked is worse again — nothing in the output tells the reader which half was verified, so the wrong half reads as confirmed. So check every graph, confirm each one is at its repo's `HEAD`, and only then continue.

### Gates 1–4 — hard stops

| Gate | Requirement | If it fails |
|---|---|---|
| **1. Atlassian MCP connected** | The Atlassian MCP server is available and `getJiraIssue` on the given key returns the issue | Say the Atlassian MCP server is not reachable and stop. Do not read the ticket from a branch name, a file, or memory |
| **2. Ticket exists and is a Story, Bug or Task** | The issue resolves, and its `issuetype` is `Story`, `Bug` or `Task` | Say what it actually is and stop — an Epic, or any type this skill does not refine, is not broken down |
| **3. Story ready** | Gate removed by user instruction — not enforced | (none) |
| **4. Every `--repo` graph is at its repo's `HEAD`** | For each `--repo`: dispatch a parallel sub-agent that reads `.ua/meta.json`'s `gitCommitHash` and compares against `git rev-parse HEAD`. All repos checked concurrently. Both must be equal for **every** `--repo` | Say which repo's graph is stale, give both values (graph hash and HEAD), and stop. Do not read the issue in depth, do not fetch Confluence pages, do not split the work, and do not write any file. **Never run `/understand` to fix it** — report the blocker and end the run |

How to check gate 3:

- `getJiraIssue` with `labels` in the `fields` list, and look for the exact string `ready_for_refinement`. A similarly-named label (`ready-for-refinement`, `ready_for_refine`) is **not** this label; do not accept it as close enough. This check applies to **Stories only**: a Bug or Task passes gate 3 without any label, so never stop one for want of it.

There is deliberately **no create-permission gate**. This skill never creates tickets, so it needs no permission to create them — the old gate asked for permission a read-only skill does not use. An issue whose sub-tasks already exist on Jira passes the gates unchanged: those sub-tasks are context to read and report, not a reason to stop and not something to re-create.

How to check gate 4:

Dispatch **one sub-agent per `--repo`**, all running concurrently. Each sub-agent:

1. Reads the graph's recorded commit:
   ```bash
   node -p "require('<accountia-all>/<repo>/.ua/meta.json').gitCommitHash"
   ```
2. Reads the repo's current `HEAD`:
   ```bash
   git -C <accountia-all>/<repo> rev-parse HEAD
   ```
3. Compares the two values.
4. Returns a result: `current` (hashes match) or `stale` (hashes differ), with both values.

The main agent dispatches all sub-agents in parallel, waits for all to complete, then evaluates:

- **All repos `current`** → gate 4 passes. Continue to Step 1.
- **Any repo `stale`** → gate 4 fails. **Stop the whole run.** Report which repo(s) are stale, both values for each, and end. Do **not** run `/understand` — not incremental, not full, not with `--full`, not in any form. Updating the graph is the developer's job (via `/refinement-sync`), not this skill's.

Name each repo and both values in the report, so "every graph is current" is something the developer can check rather than take on trust.

**This whole section must complete, for every `--repo`, before you continue to Step 1.** It is not a best-effort check that you report and move past: it is gate 4, and the run ends here if it cannot be satisfied. All sub-agents run concurrently — the main agent dispatches them all, waits for every one to return, and only then evaluates the results.

**Never** edit `.ua/` by hand, hand-write a `meta.json`, or point the skill at a graph from a different repo to make a check pass. **Never** run `/understand` in any form.

**Order matters:** gates 1–4 all run *before* reading the issue in depth, fetching Confluence pages, or writing any file.

Why gate 4 is a gate and not a best-effort check: this is a superrepo whose whole purpose is cross-repo development, and the graph is derived state. Refining against a graph that is behind means judging the change against code that has since moved: the split ends up wrong, a capability looks missing when it already shipped, or work is carved up along seams that no longer exist. And because a partial check leaves some repos verified and others not, the output would carry no sign of which half was judged against moved code — the stale half reads exactly as authoritative as the fresh one. So the run waits for every graph, and stops if one is not current. Note that comparing against local `HEAD` is correct *here* — the submodule is already at whatever commit it was last synced to, and the graph must match that.

Gate 3 exists because a Story's description alone is often too thin to refine safely — ACC-8592's was three lines with an undefined "all general rules apply". For a Story, the label is the reporter's signal that the spec is settled, and refining without it means inventing intent, which is the failure this skill most needs to avoid. A Bug or Task is exempt: a bug is a reported defect whose description is a reproduction, and a task is a piece of work already carved out — neither waits on a settled spec, so neither is held to the label.

## Steps

### 1. Fetch the issue — read-only

Via the Atlassian MCP server (cloudId `genieitsoultions.atlassian.net`):

- `getJiraIssue` with `fields: ["summary", "description", "status", "issuetype", "assignee", "reporter", "parent", "comment", "issuelinks", "subtasks", "labels", "priority"]` and `responseContentFormat: "markdown"`.
- `getJiraIssueRemoteIssueLinks` for linked Confluence pages and MRs.
- `getConfluencePage` (markdown) for **every** linked Confluence page — they are part of the spec.
- If the issue has a parent, fetch the parent's summary/description too (sub-tasks often inherit context). **Read every comment with care.** Comments on the issue are Q&A between the reporter and the team — they clarify, narrow, correct, or even reverse parts of the main description. A comment that says "no, it should be X not Y" or "the field is optional, not required" is as binding as the description itself. Never skip the comments and never treat them as mere chatter: a refinement that ignores a clarifying comment produces sub-tasks that contradict what was actually decided.
- **If the issue already has sub-tasks, fetch each one** (`getJiraIssue`, with `description`). They are evidence of what the last refinement decided and how the work was carved. Read them for context only — they are **not** the spec, **not** a source to copy from, and **not** a reason to stop. The issue description and the graph stay authoritative, and you still produce fresh files.

Report to the developer what already exists on the issue — the sub-task keys and titles — before writing anything, so they can see what your breakdown is replacing or differing from.

Do not use any transition/comment/update/issue-creation tool.

### 2. Ground in the knowledge graph (`.ua/`)

For each `--repo`:

1. Locate the repo under the accountia-all superrepo root (the directory containing `.claude/skills/refinement/`, i.e. three levels above this SKILL.md; if the working directory already is accountia-all, that is it).
2. Resolve `$REPO/.ua`. Gate 4 confirmed the graph is at the repo's `HEAD` — so **read it**.
3. Read the graph for the repo: project description, frameworks, layers, and the nodes/edges relevant to the issue (modules, endpoints, services, flows). This is what tells you whether the capability already exists, where the real seams are, and how big the change is — it does **not** go into the sub-task descriptions as code references (see the rules in Step 4).

Also read, as context: the superrepo `CLAUDE.md`, the repo's own `CLAUDE.md`, and `.claude/conventions.md` at accountia-all.

Tell the developer, **in the conversation**, what you grounded on and at which analyzed commit — the `gitCommitHash` from `.ua/meta.json` — so they can confirm it is the commit they expect. This is a message in your reply to the developer, **not** a section in `00-README.md`: the README carries no grounding section.

### 3. Split the work

Decide the sub-task breakdown before writing any file.

**Split along two axes: component, then business capability.**

**Axis 1 — component.** Work that spans backend and frontend becomes `[BE]` and `[FE]` sub-tasks, never one file covering both. Reasons: the two can then be reviewed and tested independently, progress is trackable per component, and the API has to exist before the UI can call it.

**Axis 2 — business capability, within a component.** An issue can need several `[BE]` sub-tasks, or several `[FE]` ones. Split them when the issue touches **distinct business capabilities** — separate API surfaces, separate aggregates, or behavior a developer could reason about and ship without the others.

How to find the grouping: read the parent issue and the knowledge graph together. The graph's endpoints, services, and aggregates show where the real seams are. An issue that says *"extend contact, extend product, and add a new free-posts endpoint"* is three capabilities, not one — the contact change, the product change, and the new endpoint share no business logic and can be reviewed and tested apart.

Worked example:

| Issue asks for | Sub-tasks |
|---|---|
| Modify `/api/contact`, modify `/api/product`, create `/api/free-posts/abc` | `[BE] … Contact`, `[BE] … Product`, `[BE] … Free Posts` — three capabilities, plus `[FE]` for the screens and `[QC]` at the end |
| Add delete-draft to one resource | a single `[BE]` sub-task — one capability |

**Do not split by technical seam.** Layers, classes, modules, packages, and "the command layer vs the persistence layer" are **not** split axes. A delete-draft capability that needs a command, a handler, a validator, a repository method, and a message constant is **one** sub-task — those pieces are one change to one capability, and splitting them produces tickets nobody can review or test alone. The same applies to FE: several components touched for one user-facing capability are still one sub-task.

**Do not split one field across tasks either.** A value and the read that returns it are one capability: a task that stores a value and a task that returns it are one sub-task, and a form that collects a value and a view that displays it are one sub-task. Component and business capability are the split axes; *the input half* and *the output half* of a single field are neither. Storing a field and returning it look independently shippable because the read can be built against a value that is not there yet — that is not two capabilities, it is one capability built in two steps.

When several sub-tasks share a component, the title after the prefix names the capability, so they stay distinguishable — `[BE] Delete a draft manual entry` rather than a numbering that says nothing. See the title rule in Step 4.

- **Features** — the issue is the parent; each sub-task is a child linking back to it.
- **Bugs and Tasks** — child sub-tasks of the parent issue, one per component, with the backend one first since the UI depends on it, plus the `[QC]` sub-task. A bug's description is often a reproduction rather than a spec: read it for the behaviour that must change, and split along component and capability just as you would for a feature.
- **Small, local, unambiguous change** — splitting adds nothing. Write a single sub-task and note in `00-README.md` why no split was made.

**Always add a `[QC]` sub-task when the work is split** — see the QC section below.

#### A sub-task that changes an API settles extend-or-add — it never assumes

When a sub-task changes an API surface, read the graph for the operations that already exist and decide **which way the change goes** before writing the file. The existing operations and their current shapes are in `.ua/` — that is the evidence, not a guess.

| Signal from the graph | Decision |
|---|---|
| The existing operation already carries comparable optional data, and one more is compatible for today's callers | **Extend** that operation |
| Every current caller would have to change, or the new data only means something in the new flow | **Add** a separate operation |
| The change alters how existing clients read an existing response | **Add**, or shape the response so current clients read it unchanged |
| Two flows would disagree about what the same field means | **Add** a separate operation |
| The capability needs the operation to be reachable where the existing one is not (different resource, different authority, different lifecycle) | **Add** a separate operation |

Record the decision, the reason, and what a current caller sees before and after in the sub-task's `## API change` section (Step 4). *"Add a field"* is not a decision — say **which** operation carries it, and whether that operation already existed.

This decision also tells you whether the API work is its own sub-task. Extending an existing operation for one capability normally stays inside that capability's sub-task; a new operation that a second capability also needs starts to look like a sub-task of its own. It is **not** by itself a reason to split the write of a field from its read — see the one-field rule above.

Order the sub-tasks so each one's dependencies land first, and state the ordering explicitly in `00-README.md`.

### 4. Write the sub-task files

Output directory:

```
<accountia-all>/docs/refinement/<ISSUE-KEY>/
```

**If `<ISSUE-KEY>/` already exists**, create a new folder with the ticket key + timestamp instead of overwriting:

```
<accountia-all>/docs/refinement/<ISSUE-KEY>-<YYYYMMDD-HHMMSS>/
```

This preserves the previous refinement for the same issue — never overwrite or merge into an existing folder. The timestamp is the current local time at the moment the folder is created.

Files:

- `00-README.md` — issue key + summary, scope (In/Out), the full sub-task list with one-line descriptions, labels, and sequencing/relationships between sub-tasks. When the issue already had sub-tasks, add an **Existing sub-tasks** section naming their keys and titles and stating how this breakdown relates to them — which ones it matches, which it replaces, and where it differs. It carries **no grounding section**: the repos, branches, commits and graph hashes you refined against are reported to the developer in the conversation (Step 2), never written into this file.
- `01-<kebab-slug>.md`, `02-...` — one file per sub-task, numbered in the order they should be built.

**Never overwrite an existing folder.** If `docs/refinement/<ISSUE-KEY>/` already exists, the files in it are a previous refinement's output — **preserve them**. Create a new folder `docs/refinement/<ISSUE-KEY>-<YYYYMMDD-HHMMSS>/` (ticket key + current local timestamp) and write the new breakdown there. Do not merge into the old folder, do not delete old files, and do not skip a file because something similar already exists. The old folder stays untouched as a record of the previous refinement.

Each implementation sub-task (`[BE]` / `[FE]`) uses this structure:

```markdown
---
title: "[BE] Record the refund payout currency in the refund API"
parent: <ISSUE-KEY>
labels: <repo>
priority: <Jira priority name> (<business justification>)
---

## Why this exists

<Two or three sentences: the gap this closes and why it matters. Not a restatement of the issue.>

## What to do

1. <A concrete action the implementer takes.>
2. <The next one.>

**Where to anchor it:** <The analogous behaviour that already exists in the repo, to mirror — described as behaviour, never as code. Omit this line when nothing analogous exists.>

## Read this before you start

**Already works — do NOT rebuild:**
- <A capability in this area the graph shows is already done.>

**Written but not reachable:**
- <Something that exists in the code but is not wired up, not rendered, or not called — so the work is to connect it, not to build it.>

## API change

**Decision:** <extend the existing operation / add a separate operation>
**Why:** <the signal from Step 3's table that settled it>
**Compatibility:** <what a current caller sees before and after>

## Acceptance Criteria

**<Theme — e.g. Header>**

- [ ] <Specific, testable requirement>
- [ ] <Another requirement>

**<Theme — e.g. Do not change anything else>**

- [ ] <Requirement>

## Ask before starting

- <The open question that belongs to THIS sub-task, and what changes if it is answered the other way.>

## Related Tasks

- Parent: <ISSUE-KEY>
- Blocked by: <sub-task, if any>
- Blocks: <sub-task, if any>
```

Rules for implementation sub-tasks:

- **Self-contained.** Each file must carry everything a developer needs — nothing depends on other files in the folder or on this conversation. An open question recorded only in `00-README.md`, or only in the chat, does not travel with the task; the file needs its own copy.
- **The title names the outcome.** Sentence case, verb-first, concrete, in the same casing as the parent issue — `[BE] Record the refund payout currency in the refund API`. The `[BE]` / `[FE]` / `[QC]` prefix already names the component, so everything after it names what the sub-task delivers.
- **`## What to do` carries the job** as a numbered list of actions, so an implementer can start without reverse-engineering the work out of the acceptance criteria. Keep `## Why this exists` to the gap, not to a summary of the issue.
- **`## Read this before you start` is required whenever the graph shows part of this capability already exists.** Naming what is already done — and anything that exists but is not wired up — is what stops the implementer rebuilding working code, or hunting for a control that was written and never rendered.
- **`## API change` is required whenever the sub-task changes an API surface**, and is settled in Step 3. A sub-task that touches no API omits the section entirely.
- **`## Ask before starting` is required whenever the issue leaves something open that the implementer would otherwise guess.** State the question and what changes if it goes the other way. Mirror it into `00-README.md`'s open-questions list for the reviewer.
- **Group the Acceptance Criteria by theme.** Four to six headed groups such as *Header*, *Field order*, *Validations*, *Do not change anything else* — so a reviewer can jump to the group they are checking rather than reading a flat run of fifteen.
- **Plain language, no code.** Write `## What to do` as the work to be done. Do **not** name classes, methods, files or directories, and do not quote code, config or test-method names — the implementer finds those from the repo, and naming them pins the ticket to code that moves. Describe the behaviour, the rule, or the outcome instead: not *"add a `DeleteManualEntryCommandHandler` beside `DeleteManualEntryAttachmentCommandHandler`"* but *"add a server-side delete for a draft manual entry, alongside the existing delete-attachment operation"*. The `**Where to anchor it**` line points at behaviour for the same reason — *"mirror how payment registration records its payout currency"*, never a class or a path.
- Keep the wording concrete about **behaviour and business rules** — the ban is on code identifiers, not on specificity. *"Refuses a refund whose amount exceeds the amount paid"* is concrete and correct; *"improve the refund flow"* is not.
- Acceptance Criteria entries are specific and independently checkable.
- **Never write Jira state** — no ticket keys are created, no MCP calls, no transitions.

#### The `[QC]` sub-task

Whenever the work is split, also produce a `[QC]` sub-task: a manual test plan for QC to run **after** the implementation sub-tasks land. It is not a summary of the implementation — it is the executable test plan for the feature as it will actually ship.

```markdown
---
title: "[QC] Test <feature name> end to end"
parent: <ISSUE-KEY>
labels: <repo>, ..., qc
priority: <Jira priority name> (<business justification>)
---

## Description

Manual test scenarios for <feature name>, covering the **main flow only**, to be run once the implementation sub-tasks are complete.

Failure, concurrency, and regression cases are deliberately not included unless the developer asks for them — this task covers the happy path and the gates that protect it.

## Prepare your test data

1. <Setup / login / navigation step>
2. <How to reach the feature>
3. <The data each scenario needs: the accounts, records or values to have in place, and what to vary between cases>
4. <Any record that must be in a specific state, e.g. partially used, so a gate can be probed without emptying it>

## Scope to Focus On

- <The invariant or rule under test — the thing most likely to break>
- <Boundary values, limits, and rounding where they exist>
- <The gates: what must be refused, and what must be confirmed before it happens>

## Out of Scope (do not raise as bugs)

- <Carried over verbatim from the issue's Out of Scope — so QC does not file tickets for deliberately excluded behavior>

## Scenarios

### 1/ <Theme — e.g. Basic Validation>

| Test Case-ID | Scenario | Steps | Expected Result |
| --- | --- | --- | --- |
| TC-1.1 | <What is being checked> | → <step> → <step> | <Observable result> |

### 2/ <Theme — e.g. Error and Edge Cases>

| Test Case-ID | Scenario | Steps | Expected Result |
| --- | --- | --- | --- |
| TC-2.1 | <What is being checked> | → <step> → <step> | <Observable result> |

## Execute Testing

| Test Case-ID | Status | Attachment (optional) |
| --- | --- | --- |
| TC-1.1 | | |

## Related Tasks

- Parent: <ISSUE-KEY>
- Blocked by: <every implementation sub-task this covers — BE, FE, ...>
- Blocks: none
```

Rules for the `[QC]` sub-task:

- **The title says what is being verified**, in the same sentence-case style as the implementation sub-tasks — `[QC] Test the refund registration form end to end`, not `[QC] Scenarios for Refund Registration Form`.
- **Blocked by every implementation sub-task** it covers, so it cannot be started early.
- **One row per independently checkable behavior.** If a row needs two unrelated setups, it is two rows.
- **Steps are arrow-separated actions** (`→ select invoice → click Refund`), not prose paragraphs.
- **Expected Result is observable** — what the tester sees, or the exact state/ledger effect. No "works correctly".
- **Main flow by default.** Cover the happy path and the gates that protect it: the status/eligibility check, the confirmation, the cascade, and the immediate consistency of reads afterwards. Do **not** add failure, concurrency, or regression sections unless the developer asks for them — a long QC task gets skimmed, and the main flow is what must be right.
- **Keep the gates.** Even in a main-flow-only task, keep the cases that prove a refused action is refused and that nothing happens without confirmation. Those are part of the flow, not extras.
- **Skip the exhaustive edge-case sweep.** One boundary case per rule is enough. Enumerating every edge case belongs in the implementation sub-tasks' Acceptance Criteria, not here.
- **Include a regression section only when asked.** When included, it proves adjacent behavior still works.
- **Keep it terse.** Drop any theme with only a trivial happy-path case into an existing section rather than giving it its own heading.
- **Out of Scope is copied, not paraphrased** — QC should not have to open the parent to learn what not to test.
- The **Execute Testing** table is left blank; QC fills it in as they run.
- Every scenario row has a matching Execute Testing row — verify the counts match before finishing.

### 5. Review gate — required

Present the output folder to the developer for review. Wait for their feedback.

- If they request changes → update the files and re-present.
- Only consider the work done when the developer approves the folder.

Do not proceed to any further step after producing the files — no Jira writes, no plan documents, no other skills.

**How the files get onto Jira is not this skill's concern.** Ticket creation is a separate step the developer runs later, on their own initiative, and possibly never. Do not invoke it, do not call it as a convenience, and do not tell the developer it is about to happen — the files are the deliverable and the skill ends here.

If you are told the sub-tasks for this issue already exist on Jira, that is still not a reason to stop, to skip the files, or to run anything: write the files, note the existing sub-tasks in `00-README.md`, and leave the reconciliation to the developer.

## Conventions

- **Title prefixes:** `[BE]` backend, `[FE]` frontend, `[QC]` scenarios. Match the casing already used on the issue and its siblings, and keep the title itself sentence case — everything after the prefix names the outcome, not a component or a part number.
- **Priority:** use Jira's own names (`Major`, `Minor`, ...) with a written justification, not an invented scale.
- **Output is Markdown** throughout — `##` headings, `**bold**`, `- [ ]` checkboxes, tables for scenarios, `---` between tasks.
- **Written for the implementer, not the reporter.** A sub-task opens with the gap it closes, then a numbered `## What to do`, then what already exists and must not be rebuilt, then acceptance criteria grouped by theme — so a developer can start from the file alone and does not have to open the issue to learn what to do.
- **No code in the deliverable.** Describe behaviour and business rules, not the code that implements them — no class, method, file or directory names, no code snippets, and no `file:line` references. Use `` `backticks` `` for user-visible labels and literal values (a status such as `DRAFT`, an HTTP verb, a field label), not for class or method identifiers.

## What NOT to do

- Don't transition, edit, comment, assign, or create anything in Jira; don't call `start-ticket`.
- Don't invoke `/refinement:create`, or any other skill, from this one — and don't create Jira tickets from the files yourself.
- Don't stop, skip the files, or thin the breakdown because the issue already has sub-tasks on Jira.
- Don't copy the existing sub-task descriptions into the new files, or treat them as the spec — the issue description and the graph are authoritative.
- Don't pile new files on top of a previous run's folder without rewriting it, and don't leave files for sub-tasks that no longer exist.
- Don't produce plan documents or link to `docs/plans/`.
- Don't write a `PRODUCT.md`, a `TECH.md`, or any spec document — this skill produces sub-task definitions, not specs.
- Don't implement the issue — no code, and `implement-specs` is not part of this skill.
- Don't bundle backend and frontend into one sub-task.
- Don't omit the `[QC]` sub-task when the work is split.
- Don't infer the repo from the issue; `--repo` is explicit.
- Don't name classes, methods, files or directories in a sub-task, and don't paste code, config or test-method names into one — describe the behaviour and the rules instead.
- Don't assume how an API change lands. Decide extend-or-add from the graph and record it in `## API change`; a sub-task that only says "add a field" has not made the decision.
- Don't leave an open question only in `00-README.md` or only in the chat — the sub-task it belongs to keeps its own copy of it.
- Don't invent a sub-task layout of your own. The Step 4 structure is the shape; a file that does not follow it is not ready for review.
- Don't generate sub-task files before both the spec (step 1) and the graph (step 2) are read.
- Don't continue past a `--repo` whose graph is stale, and don't write any file while one is behind. Gate 4 has to be satisfied for every repo before Step 1.
- **Never run `/understand`** — not incremental, not full, not with `--full`, not in any form. Updating the graph is the developer's job (via `/refinement-sync`), not this skill's.
- Don't treat a stale graph as a caveat to note and move past. If any repo's graph is not at its `HEAD`, stop and report — don't write the files anyway.
- Don't substitute reading the repo's source by hand for its graph, and don't present a source-grounded breakdown as if the graph had confirmed it. Say the graph is stale and stop, rather than producing output that mixes the two.
- Don't hand-edit `.ua/` or `meta.json`, or point the skill at another repo's graph to make gate 4 pass.
- Don't write a grounding section into `00-README.md`. The repos, branches, commits and graph hashes you refined against go in your reply to the developer, not in the file.

## Output location

`<accountia-all>/docs/refinement/<ISSUE-KEY>/` — the accountia-all checkout is the directory that contains `.claude/skills/refinement/`.

If `<ISSUE-KEY>/` already exists, write to `<accountia-all>/docs/refinement/<ISSUE-KEY>-<YYYYMMDD-HHMMSS>/` instead. Never overwrite a previous refinement.
