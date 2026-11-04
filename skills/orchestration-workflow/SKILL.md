---
name: orchestration-workflow
description: Run a Jira ticket end to end — preflight gates, ticket breakdown, implementation plans, then subagent-driven implementation in per-repo worktrees. Invoke with /orchestration-workflow <TICKET>.
disable-model-invocation: true
---

# Orchestration Workflow

One Jira ticket in, implemented code in a per-repo worktree out. Four phases, each ending on a **gate**: the run advances only when the gate passes, and a failed gate ends the run.

Every delegation goes through **Orca orchestration** on one bound Run. This skill supplies the phase order, the paths, and the gates; Orca supplies the coordination.

```
/orchestration-workflow ACC-1234
```

## Dependencies

This skill reads sibling skills: `to-tickets` (mattpocock/skills), `design-to-tickets` (Accountia), `build-plan` (Accountia), `jira-ticket` (Accountia), `accountia-conventions` (Accountia), `review-loop` (Accountia). Before anything else, check that each has a `SKILL.md` in a folder beside this skill's own. For each missing one, ask the user, then install it with `npx skills add <source> --skill <name> -a claude-code -y`, adding `-g` when this skill sits under the home directory. The Accountia source is the `source` recorded for this skill in `skills-lock.json`; if none is recorded, ask for it.

## Input

The argument is a ticket key (`ACC-1234`) or a browse URL (`https://genieitsoultions.atlassian.net/browse/ACC-1234`) — extract the key from the URL. No argument: ask for one; never infer it from a branch name.

Everything else is derived. There is no `--repo` flag: the phase 1 inference settles the repos.

## Resolve the workspace

`$WS` is the `workspace` directory: the nearest ancestor of the current directory that contains `workspace/`. Today that is `D:\projects\proj-accountia\workspace`.

- No ancestor contains `workspace/` → stop and say so. Do not create one.
- `$WS` is the whole managed area. `<root>/accountia-all/` is the superrepo checkout — detached-HEAD submodules, a different HEAD from the worktrees, no graphs. The run never reads it, never writes it, never uses its submodule checkouts as a repo path, and never checks anything out inside it.
- Git writes only its own administrative metadata under `accountia-all/.git/modules/` when a worktree is added in phase 4. That is git's bookkeeping, not a working location.

Layout, command recipes, and the traps behind them: [references/workspace-layout.md](references/workspace-layout.md).

## Bind the delegation layer

Before phase 1:

1. Resolve the executable once — `ORCA_CLI_COMMAND`, else `orca-dev` when `ORCA_DEV_REPO_ROOT` is set, else `orca-ide` on Linux outside an Orca terminal, else `orca`. Reuse it for every command in the run. If it cannot run, report its exact error and stop; do not fall through to another binary.
2. `ORCA skills get orchestration` and follow the contract it returns for every dispatch in this run.
3. `ORCA orchestration run-create --objective "<TICKET> — <summary>"` to bind one Run. Every later dispatch targets it.

**Pick the worktree per dispatch, never `current`.** `--worktree current` resolves to the coordinator's own worktree, so a frontend task dispatched that way runs inside the backend tree. Every worker that touches a repo names its own tree explicitly:

```
--worktree path:<absolute path to $WS/<repo>/main>
```

A worker that touches one repo runs in that repo's `main`. A worker that reads both repos (the tickets and planning workers) still gets an explicit path, the primary repo's `main`, not `current`.

Dispatch shapes, the task-spec contract, waves, and the nested-worker depth budget: [references/delegation.md](references/delegation.md).

## The knowledge graph is the evidence

Every claim about what the code does — that a capability exists, that a handler is already called, that a field is already populated, that a screen already has a branch — is answered from `$WS/<repo>/main/.ua/knowledge-graph.json`, not from opening the source tree. That is what phase 1 verified the graph for.

The graph answers, per node: `id`, `type` (`file` / `class` / `function` / `table` / `config` / `document` / `service` / `pipeline`), `filePath`, `lineRange`, `summary` (what it does, in prose), `tags`, `complexity`; and per edge: `calls` (3.5k in the backend), `imports` (24k), `contains` (10.4k), `exports` (9.1k), `inherits`, `implements`, `tested_by`, `depends_on`, `related`, `deploys`, `triggers`, `configures`, `documents`. It also carries `layers` (architecture) and `tour`. Neither repo produces `endpoint` nodes: an HTTP operation is a `function` node on a `*Controller` class, and `calls` edges run function → function/class.

**Query the graph, never load it.** The backend file is 24 MB (~6.1M tokens) and the frontend's is 8.9 MB — they do not fit in a context. Recipes: [references/delegation.md](references/delegation.md#querying-the-graph--never-read-it-whole).

**Line ranges are carried; provenance still matters.** `class` and `function` nodes carry `lineRange: [start, end]` — 10,289 of the backend's 15,499 nodes. A plan may cite a range it took from the node. A range the plan got by opening the file to find out what the code does is the leak to watch for: ask for the node id alongside every claim, and a claim with no node id is the one to re-check.

So the split is:

| Question | Answered from |
|---|---|
| Does this capability exist? Where does it live? What calls it? What tests it? Which layer? | **Graph** (queried, capped — never loaded whole) |
| Which exact line does the edit go in? What is the current method body? | Source, and only after the graph has named the file |

A plan may name files and give edit instructions; it may read the one file it is about to change to place the edit. What it must not do is *investigate* by reading the tree: that is slower, misses cross-repo edges, and produces confident claims the graph would have refuted.

If a graph cannot answer something — it is stale, the node is absent, or the question is about a UI placement no node records — say so explicitly rather than substituting a source-tree answer that reads as graph-grounded.

## Phases

| Phase | Produces | Gate |
|---|---|---|
| 1. Preflight | verified ticket, verified graph | G1 Jira · G2 `/understand` · G3 graphs current |
| 2. Tickets | the ticket folder `$WS/docs/design/plans/<DD-MM-YYYY>-<TICKET>-<slug>/` | human approves the folder |
| 3. Implementation plans | `$WS/docs/build/plans/<TICKET>/` | human approves the plans |
| 4. Implementation | one worktree per repo, committed | every plan implemented and reviewed |

Title every task `<Pn> <phase> <ticket>` and post one `status` message on the Run when a gate passes, so the run is readable while it is in flight — shapes and the cost of each: [references/delegation.md](references/delegation.md#announcing-phases).

### Phase 1 — Preflight

Three gates, all before phase 2. Each either passes or ends the run.

**Repos.** Read the ticket's `issuetype`, `components`, `labels`, and description: `[BE]` / backend wording → `accountia-backend`; `[FE]` / frontend wording → `accountia-frontend`; both when the ticket spans both. Those two repos are the whole set — a ticket that implies any other repo stops the run with a message naming it. Report the inferred list once, then continue.

**G1 — Jira reachable, ticket exists.** `getJiraIssue` (Atlassian MCP, cloudId `genieitsoultions.atlassian.net`, `responseContentFormat: markdown`, fields `summary description status issuetype assignee reporter parent comment issuelinks subtasks labels components`) returns the issue. Unreachable or absent → stop. The ticket is the only source of intent.

**G2 — `/understand` available.** The `understand-anything:understand` skill resolves. Missing → stop: the graphs cannot be refreshed, and phase 3 cannot be grounded.

**G3 — every repo's graph is at its main-worktree HEAD.** For each inferred repo, compare `$WS/<repo>/main/.ua/meta.json`'s `gitCommitHash` with `git -C $WS/<repo>/main rev-parse HEAD`.

- Equal → that repo passes.
- Missing or unequal → **refresh it**, in one parallel wave, one worker per stale repo:

  ```
  UNDERSTAND_NO_WORKTREE_REDIRECT=1  /understand <absolute path to $WS/<repo>/main>
  ```

  Without the variable, `/understand` inside a worktree redirects its output to `accountia-all/.git/modules/<repo>` and the graph never reaches the worktree. Pass `--full` only when the repo has no graph; an existing graph gets the incremental path.

  Wait for every `worker_done`, re-compare, and pass only when every graph equals its HEAD. Still unequal → stop and report both hashes per repo.

A graph beside `main` (`$WS/<repo>/.ua`) belongs to no checkout the run uses. Leave it alone — do not read, move, or delete it.

G1–G3 all passing closes phase 1: post `status` with `--phase "preflight"`, naming the ticket key and type and each repo's graph hash against its HEAD.

Phase 1 refreshes the graph; the later phases will not. The workflow owns freshness, so phases 2 and 3 run against a verified graph.

### Phase 2 — Tickets

Dispatch one worker, cwd under `$WS`, `--worktree path:$WS/<primary repo>/main`, task spec:

```
/design-to-tickets <TICKET>
```

The ticket is the Jira spec. The worker runs the skill through its step 2 and stops there: the gate below replaces its review (step 3), and Jira stays read-only, so its step 4 creates no issues. The skill writes the **ticket folder** `$WS/docs/design/plans/<DD-MM-YYYY>-<TICKET>-<slug>/`, one `<NN>-<slug>.md` per ticket with its blocking edges. The worker reports the exact folder path.

The gate: the tickets are in the ticket folder, verified by listing it, then the developer reviews that folder.

```
plannotator annotate "<ticket folder>" --gate --json
```

- `approved` → post `status` with `--phase "tickets"` (folder, ticket count, verdict), then phase 3.
- Annotations → re-dispatch the tickets worker with that feedback, then re-present.
- Anything else → stay in phase 2.

### Phase 3 — Implementation plans

Dispatch one worker, `--worktree path:$WS/<primary repo>/main`, task spec:

```
/build-plan <TICKET>
```

with the approved ticket folder as added input: after the Jira ticket, the worker reads every ticket in the folder, orders each plan's tasks by the tickets' blocking edges, and makes every ticket's acceptance criteria owned by some task. It runs the skill through its step 3 and stops there: the gate below replaces its review (step 4). The skill writes `$WS/docs/build/plans/<TICKET>/`: `design.md` plus one `plan-<NN>-<module>-<slug>.md` per repo, in dependency order.

Ground the plans in the knowledge graphs — the graph is the evidence for every "already exists", "already called", and "already returns" claim, and for where the change belongs. Reading source is for placing an edit in a file the graph already named, never for discovering the design. Every code claim in `design.md` and the plans cites a graph node (`file:` / `class:` / `function:` / `table:`); a line range is fine when it came from that node's `lineRange`, and a plan full of `:257-269` with no node id was produced by reading the tree.

The gate: `plannotator annotate <plan-01> <plan-02> … --gate --json`, same loop as phase 2, re-dispatching the planning worker for each round. Passing it posts `status` with `--phase "plans"` — plan count and the graph commit each was written against.

### Phase 4 — Implementation

Map each plan to its repo by the `<module>` in its file name (`plan-<NN>-<module>-<slug>.md`). For each repo, create the worktree **from the main worktree**:

```
git -C $WS/<repo>/main worktree add $WS/<repo>/<TICKET>-<slug> -b <case-type>/<TICKET>-<slug>
```

`<case-type>`: Story → `feat`, Bug → `fix`, Task → `feat`; `<slug>` is the ticket title as a slug per the [development conventions](../accountia-conventions/conventions.md).

Then dispatch one worker per plan, each running `/superpowers:subagent-driven-development` **with cwd inside its own worktree** and the absolute plan path, in plan number order. SDD dispatches its per-task implementers and reviewers as Orca workers on the same Run — its own nested workers, no second `run-create`. One implementer per worktree at a time.

When every plan is complete and reviewed: release the settled workers, post `status` with `--phase "implementation"` naming each worktree's branch and committed range, and report the same to the developer. That ends the run.

Commits stay inside the worktrees. The run never pushes, never opens an MR, never merges, and never runs `finishing-a-development-branch` — the developer decides what happens to the branches.

## Hard rules

1. Every delegation is an Orca dispatch on the bound Run. Coordination without Orca runtime state is not this skill's coordination.
2. Every claim about existing code is answered from the knowledge graph — queried with a cap, never loaded whole; source is opened only to place an edit in a file the graph already named.
3. Worktrees are created from `$WS/<repo>/main`, always.
4. `accountia-all/` is out of bounds as a working location.
5. Gates are binary: pass, or end the run with the reason. A gate that could not be checked has not passed.
6. Jira is read-only: fetch, never transition, edit, comment, or create.
7. Repos are `accountia-backend` and `accountia-frontend`, inferred from the ticket.
8. Commits are local to a worktree; push, MR, and merge are the developer's call, made later.

## Stop conditions

Report the gate, what was expected, and what was found. Then end the run.

| Condition | Report |
|---|---|
| Jira unreachable, or the key does not resolve | which gate failed, plus the exact error |
| Ticket implies a repo other than backend/frontend | the repo named in the ticket |
| `/understand` unavailable | that G2 failed |
| Graph still unequal after a refresh | repo, graph hash, HEAD hash |
| Reviewer did not approve a folder | the annotations left unaddressed |
| An Orca worker is lost or `unverifiable` | that this is a checkpoint, not proof to retry or abandon |

## Not this skill

Orca's `orchestration` guide is the authority on Run/Task/Dispatch semantics, ask/reply, waits, and recovery. This skill orders the Accountia phases around it. For a plain ownership handoff with no supervision, or for terminal and worktree commands outside this workflow, use that skill directly.
