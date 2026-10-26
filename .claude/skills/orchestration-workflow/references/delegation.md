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
<repo>/main/.ua/knowledge-graph.json — it answers what exists, what calls what,
which tests cover what, and which layer a file belongs to. The graph has no line
numbers, so do not cite file:line from it; open the source only to place an edit
in a file the graph has already named.
```

A worker that reports findings as `File.java:257-269` without saying it derived them from source is hiding where the evidence came from. Ask for the graph node id alongside every code claim; a claim with no node id is the one to re-check.

Each spec also names its worktree explicitly — `--worktree path:<absolute path to $WS/<repo>/main>`. Never `current`: that resolves to the coordinator's worktree, so a frontend task runs in the backend tree and every relative path in it points at the wrong repo.

| Worker | Worktree |
|---|---|
| graph refresh for a repo | `path:$WS/<that repo>/main` |
| refinement (both repos) | `path:$WS/<primary repo>/main`, or the coordinator's tree — it reads graphs by absolute path |
| brainstorming note | any one repo, but explicitly named |
| plan for a `[BE]` spec | `path:$WS/accountia-backend/main` |
| plan for an `[FE]` spec | `path:$WS/accountia-frontend/main` |
| SDD for a plan | the phase-4 worktree for that plan's repo |

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
  the graph node (file:/class:/function:/endpoint:), not a source line range. Write the plan into
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
