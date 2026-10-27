# Delegation through Orca orchestration

One Run, bound before phase 1, owns every dispatch in the workflow. `ORCA skills get orchestration` printed by the executable resolved for this session is the authority on the mechanics; this file fixes the shapes specific to these four phases.

## Run lifecycle

```
ORCA status --json                                    # session present?
ORCA skills get orchestration                         # the contract to follow
ORCA orchestration run-create --objective "<TICKET> — <summary>" --json
  ... phases 1-4 ...
ORCA orchestration check --wait --types "worker_done,escalation,question" --timeout-ms 900000 --json
```

Each phase dispatches its workers, then waits. A timeout or empty `check` is a checkpoint, not a failure — keep waiting, or enumerate with `worker-list` after three consecutive empties, per the guide. A lost or `unverifiable` worker is absence, not proof to stop, retry, or abandon.

At the end, `worker-release` each settled dispatch.

## Announcing phases

Two mechanisms, and only two. A decision gate is not one of them: the contract reserves gates for coordinator-owned Task-DAG decisions, and a phase boundary is a report, not a decision.

**Name every task by phase.** Both `task-create` and `worker-start` take `--task-title`, and `--display-name` for the worker row in the UI. Title each one `<Pn> <phase> <ticket>`:

```
P1 G3 refresh backend graph ACC-1234
P2 refinement ACC-1234
P3a brainstorming ACC-1234
P3b plan BE ACC-1234
P4 implementation BE ACC-1234
```

This costs nothing and adds no message: `task-list` becomes readable while the run is in flight, and a task that failed is identifiable by name rather than by tracing its spec back to a phase.

**Post one `status` message per gate.** After a gate passes, announce it on the Run:

```bash
ORCA orchestration send --type status --phase "refinement" \
  --subject "P2 gate passed — refinement approved" \
  --body "<folder, file count, approval verdict>" --run <run_id> --json
```

The coordinator omits `--from`. `--phase` is free text carried in the message payload; use one of `preflight`, `refinement`, `plans`, `implementation` — the four gate names this workflow posts — so the run reads as a sequence.

Cost: each `status` message lands in the Run inbox, and `check` hands back the whole FIFO batch until it is acknowledged, so every one is a row the coordinator must drain. Post at gate boundaries only — four per run — never per worker.

## The task-spec contract

Every `worker-start --spec` carries five things. A spec missing any of them is under-specified and will come back as a question.

| Part | What it names |
|---|---|
| **Target** | the exact directory, folder, or worktree in scope |
| **Change** | the concrete result to produce — the skill to run, with its arguments |
| **Constraints** | read-only areas, what must not be touched, values to use verbatim |
| **Ownership** | what this worker may edit |
| **Observable acceptance** | the file, hash match, or verdict that proves completion |

## Grounding and worktree rules for every dispatch

Each spec's **Constraints** must carry the grounding rule, verbatim or tighter:

```
Ground every claim about existing code in the knowledge graph at
<repo>/main/.ua/knowledge-graph.json — query it, never load it whole. The graph
is 24 MB in accountia-backend and 8.9 MB in accountia-frontend; reading it into
context is not possible. It answers what exists, what calls what, which tests
cover what, and which layer a file belongs to. `class` and `function` nodes
carry `lineRange: [start, end]`, so a line range is allowed when it came from
the node; a range you got by opening the file to investigate is not. Cite the
node id alongside every code claim, and open the source only to place an edit in
a file the graph has already named.
```

A worker that reports findings as `File.java:257-269` with no node id alongside it is hiding where the evidence came from. A claim with no node id is the one to re-check.

Each spec also names its worktree explicitly — `--worktree path:<absolute path to $WS/<repo>/main>`. Never `current`: that resolves to the coordinator's worktree, so a frontend task runs in the backend tree and every relative path in it points at the wrong repo.

| Worker | Worktree |
|---|---|
| graph refresh for a repo | `path:$WS/<that repo>/main` |
| refinement (both repos) | `path:$WS/<primary repo>/main`, or the coordinator's tree — it reads graphs by absolute path |
| brainstorming note | any one repo, but explicitly named |
| plan for a `[BE]` spec | `path:$WS/accountia-backend/main` |
| plan for an `[FE]` spec | `path:$WS/accountia-frontend/main` |
| SDD for a plan | the phase-4 worktree for that plan's repo |

## Querying the graph — never read it whole

`knowledge-graph.json` is 24 MB in `accountia-backend` (~6.1M tokens) and 8.9 MB
in `accountia-frontend`. A filtered, capped lookup returns ~1.5k tokens; the
whole file cannot fit in a context and is not meant to.

Point at it once per dispatch — POSIX `KG=$WS/<repo>/main/.ua/knowledge-graph.json`,
PowerShell `$KG = "$WS/<repo>/main/.ua/knowledge-graph.json"`.

The recipes below use `node`, which the graph tooling already requires, so they
work wherever `.ua/` exists. Where `jq` is installed it is a valid substitute —
`jq '[.nodes[] | select(.filePath == "src/app.ts")][:15]' "$KG"` for the node
lookup, cap included — but nothing here depends on it.

**1. Project metadata** — small, safe to read whole:

```bash
node -p "JSON.stringify(require(process.argv[1]).project,null,1)" "$KG"
```

**2. Find nodes by keyword** — searches `id` + `name` + `summary` + `tags`,
caps at 15, trims to the fields that matter:

```bash
node -e '
const g=require(process.argv[1]), kw=process.argv[2].toLowerCase().split(/\s+/);
const hit=n=>kw.every(k=>(n.id+" "+n.name+" "+(n.summary||"")+" "+(n.tags||[]).join(" ")).toLowerCase().includes(k));
console.log(JSON.stringify(g.nodes.filter(hit).slice(0,15)
  .map(n=>({id:n.id,type:n.type,filePath:n.filePath,lineRange:n.lineRange,summary:n.summary})),null,1));
' "$KG" "manual entry delete"
```

**3. Who calls it / what it calls** — the 1-hop neighbourhood of a node id:

```bash
node -e '
const g=require(process.argv[1]), id=process.argv[2], cap=25;
const pick=e=>({type:e.type,source:e.source,target:e.target});
console.log(JSON.stringify({incoming:g.edges.filter(e=>e.target===id).slice(0,cap).map(pick),
  outgoing:g.edges.filter(e=>e.source===id).slice(0,cap).map(pick)},null,1));
' "$KG" "function:<relative-path>:<name>"
```

`calls` edges run function → function/class, not into an `endpoint` node.
Endpoints in these repos are modelled as `function` nodes on a `*Controller`
class — the graph produces no `endpoint` nodes for either repo.

**4. Which architectural layer a path sits in:**

```bash
node -e '
const g=require(process.argv[1]), f=process.argv[2];
console.log(g.layers.filter(l=>l.nodeIds.some(id=>id.includes(f))).map(l=>l.name));
' "$KG" "accounting/commands/validators"
```

**5. Which tests cover a file** — `tested_by` edges:

```bash
node -e '
const g=require(process.argv[1]), f=process.argv[2];
console.log(JSON.stringify(g.edges.filter(e=>e.type==="tested_by"
  && (e.source.includes(f)||e.target.includes(f))).slice(0,20),null,1));
' "$KG" "<relative-path>"
```

Rules: cap every result with `.slice(0, N)`; never `JSON.stringify` a whole
`g.nodes`; never `cat` the file. If a keyword search returns no hits, widen the
keyword or search `tags` — do not fall back to reading the source tree.

## One spec per phase

**Phase 1 — graph refresh**

```
Target: $WS/accountia-backend/main
Change: run /understand on this directory, incremental (a graph already exists there)
Constraints: UNDERSTAND_NO_WORKTREE_REDIRECT=1 must be set — without it the graph is
  written into accountia-all/.git/modules/accountia-backend instead of .ua/.
  Do not read, move, or delete $WS/accountia-backend/.ua.
  Do not run --full; do not touch any file besides .ua/.
Ownership: $WS/accountia-backend/main/.ua/ only.
Acceptance: .ua/meta.json gitCommitHash equals `git -C $WS/accountia-backend/main rev-parse HEAD`.
  Report both hashes.
```

**Phase 2 — refinement**

```
Target: <root> (cwd), output to $WS/docs/refinement/<TICKET>/
Change: run /refinement <TICKET> --repo workspace/accountia-backend/main,workspace/accountia-frontend/main
Constraints: --repo paths stay relative to the root — an absolute path or a bare repo name
  does not resolve. The skill writes into <root>/docs/refinement/; report the exact folder
  it produced and do not move it yourself — the coordinator relocates it to $WS/docs.
  Jira is read-only. Do not implement anything, do not create a branch, do not commit.
Ownership: <root>/docs/refinement/ only.
Acceptance: 00-README.md plus one numbered file per sub-task; report the folder path and file list.
```

**Phase 3 — planning**

```
Target: $WS/docs/refinement/<TICKET>/<spec file>, output to $WS/docs/plans/<TICKET>/
Change: run /superpowers:brainstorming (once) then /superpowers:writing-plans for this one spec
Constraints: ground every existing-code claim in <repo>/main/.ua/knowledge-graph.json and cite
  the graph node (file:/class:/function:/table:), not a source line range. Write the plan into
  $WS/docs/plans/<TICKET>/ (not docs/superpowers/plans/). The [QC] spec is a manual test plan and
  gets no implementation plan. Do not implement.
Ownership: one plan file, plus your rows in the folder README.
Acceptance: one plan file whose tasks cover every acceptance criterion in the spec; report its
  path and the graph nodes you grounded it on.
```

The brainstorming worker that precedes these takes the whole refinement folder as its target and settles the specs' open questions; its output is the input the planning workers quote.

**Phase 4 — implementation**

```
Target: $WS/<repo>/<TICKET>-<slug> (the worktree), plan at $WS/docs/plans/<TICKET>/<plan>.md
Change: run /superpowers:subagent-driven-development with cwd in the worktree and the absolute plan path
Constraints: local commits only — never push, never open an MR, never merge, never run
  finishing-a-development-branch. Dispatch your per-task implementers and reviewers as Orca
  workers on this same Run; do not create a new Run.
Ownership: inside the worktree only.
Acceptance: every plan task complete and reviewed; report the branch name and the commit range.
```

## Waves and ordering

Run in parallel:

- graph refreshes across repos (independent trees)
- nothing else, in phase 1

Run in sequence:

- brainstorming before the planning workers — its answers are their input
- one implementer per worktree at a time; two would conflict on the same tree
- backend before frontend when the FE plan consumes an API the BE plan introduces

A plan's own tasks are SDD's business, not this coordinator's — do not flatten them into a coordinator wave.

## MCP registration

The Atlassian MCP server is declared in `<root>/accountia-all/.mcp.json` and registered per project directory. `D:\projects\proj-accountia` has it; `agent-skill` does not. Start the run from the root or a directory under it, or G1 fails with a server-not-reachable error that reads like a Jira outage.

## Nested workers and the depth budget

SDD dispatches an implementer and a reviewer per task. Those are workers of the SDD worker. Orca's guide states nested workers obey a depth limit and a new Run does not reset the caller's depth.

So an SDD worker dispatched by this workflow is already one level down, and its implementers are two. At the limit:

- the SDD worker still runs its per-task dispatch itself with `worker-start` on the same Run, and
- if the harness refuses the depth, SDD runs those tasks inline rather than the coordinator flattening the plan into its own wave.

Never resolve a depth refusal by having the coordinator dispatch implementers directly. That would put the review loop — spec review, quality review, fix rounds — outside the worker that owns the plan.

## Follow-up dispatches

A settled worker may be reused for an immediate follow-up on the same Task: send it the review feedback and let it amend. A fresh worker is right when the original is gone, or when the work changed shape enough that its context is a liability.

Review rounds in phases 2 and 3 are follow-ups: the same refinement or plan worker, plus the annotations.

## What the coordinator reports

Per phase, in the workflow's own voice:

- which gate passed, with the evidence (the ticket key and type; each repo's graph hash against its HEAD; the approval verdict)
- what was produced (folder, file count, branch, commit range)
- what it ruled on, and what that costs if the ruling was wrong

Not as success: a gate it skipped, a graph it could not verify, a folder nobody approved, a worker whose outcome is `unverifiable`, or a task "probably finished". None of those are evidence.
