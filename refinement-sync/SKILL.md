---
name: refinement:sync
description: Use to bring the accountia superrepo's submodule knowledge graphs (`.ua/`) up to the latest default-branch code and rebuild them. Defaults to **every** submodule — no `--repo` needed — and is built to run unattended (e.g. from a cron job): it never asks a question and never waits on a prompt. For each repo it fast-forwards the submodule to its remote default branch, clears that repo's leftover analysis scratch, then **tries incremental update first** — `@understand --repo <repo>` (no `--full`) — and only falls back to a full rebuild (`@understand --repo <repo> --full`) when the incremental path fails or cannot handle the change. Runs each repo's analysis as a **parallel sub-agent** so all repos are processed concurrently. Verifies each rebuilt graph landed on the synced commit before reporting, and names any repo it could not bring current instead of stopping the whole run. Optional `--repo` narrows a manual run. Never touches Jira, never writes sub-task files, never hand-edits the graph artifacts, never touches the superrepo.
---

# Refinement — Sync

Bring every submodule of the accountia superrepo to its latest default-branch code, then update each repo's knowledge graph (`.ua/`) against that commit — **incremental first, full as fallback** — using **parallel sub-agents** per repo, and confirm it landed.

`/refinement` treats current graphs as a gate before it will split an issue; this is how those graphs get current. Run with no arguments, it does this for **every** submodule — the form a scheduled job uses. Code first, graph second: a graph is only worth comparing once the code has stopped moving, and the comparison is only meaningful against the commit the sync just produced.

**Built to run unattended.** This skill never asks a question and never waits for a confirmation. There is nobody at the keyboard when a cron job fires one, so anything that would normally prompt has a settled answer here — and the answer is always "carry on, and say what you did in the report". A run that blocks on a prompt does not fail loudly; it hangs, and the graphs silently go stale.

**Incremental first, full as fallback.** The incremental path (`@understand --repo <repo>` without `--full`) is tried first. If it succeeds and lands the graph on the synced commit, the repo is done — no full rebuild needed. If the incremental path fails (error, cannot handle the change, lands on the wrong commit, or produces an incomplete graph), fall back to a full rebuild (`@understand --repo <repo> --full`) automatically. The full rebuild is the safety net, not the default.

**Parallel sub-agents per repo.** Each repo's analysis (step 3 onward) is dispatched as an independent sub-agent so all repos are processed concurrently rather than sequentially. A sub-agent handles one repo end-to-end: clear scratch, run `@understand` (incremental then full if needed), verify the graph landed. The main agent dispatches all sub-agents, collects their results, and writes the final report. A sub-agent failure in one repo does not affect the others.

**What it touches:** each submodule's branch (fast-forward only), its `.ua/` scratch directories, and `.ua/`'s graph artifacts via `@understand`. **What it never touches:** Jira, `docs/refinement/`, the superrepo itself, and the graph artifacts by hand. It never overwrites or discards your uncommitted work either — the most it does is stash it, and the stash is left for you to restore yourself.

## Input

```
/refinement:sync [--repo <repo>[,<repo>...]]
```

- **No arguments → every submodule of the superrepo.** This is the normal form and the one a scheduler uses. There is nothing to ask and nothing to narrow: "all of them" is the answer.
- `--repo` — optional, and only to narrow a manual run. One or more submodule names exactly as they appear in `.gitmodules` (the `path` listed by `git config --file .gitmodules --get-regexp path`; e.g. `accountia-backend`, `accountia-frontend`), comma-separated or repeated, whitespace around the commas trimmed. A prefix, an abbreviation, or a component token (`BE`, `FE`, `QC`) is **not** a repo name.
- There is no issue key. This skill never reads Jira.

## Hard rules

These are not negotiable, even under pressure to move fast:

1. **Never ask, and never wait on a prompt.** The run is unattended. Do not ask the developer which repos, do not ask whether to continue, do not wait for a confirmation. Every question the skill or its tools might raise has a settled answer below; act on it and record what you did in the report. A blocking prompt is the one failure mode that looks like success.
2. **Default to every submodule.** With no `--repo`, cover all of them — not a subset, not "the ones with graphs", not a guess. An unresolvable `--repo` name is a named stop in the report, never a question.
3. **Incremental first, full as fallback.** Try `@understand --repo <repo>` (no `--full`) first. If it succeeds and the graph lands on the synced commit, done. If it fails — error, incomplete graph, wrong commit, or any unrecoverable state — fall back to `@understand --repo <repo> --full` automatically. Never ask the developer which path to take; the fallback is unconditional.
4. **Use parallel sub-agents per repo.** Dispatch each repo's analysis (steps 3–5) as an independent sub-agent. All repos run concurrently. The main agent dispatches, collects results, and writes the report. Do not run repos sequentially unless a sub-agent fails and must be retried inline.
5. **Never hand-edit the graph artifacts** — `knowledge-graph.json`, `meta.json`, `fingerprints.json`. `@understand` rebuilds them, or they are wrong. (Clearing the scratch directories under `.ua/` in step 3 is expected cleanup, not hand-editing.)
6. **Never rebase, reset, force, or overwrite.** Fast-forward only; `git stash -u` is the ceiling for uncommitted work, and divergence is a stop, not a problem to push through.
7. **Never touch the superrepo** — no branch switch, no commits, no moving the superproject's submodule pointers. (Running `git submodule update --init` in step 1 to check out a submodule that has no checkout yet is checkout setup, not touching the superrepo — it does not move a pointer.)
8. **Never write `docs/refinement/`, never run `/refinement` or `/refinement:create`, never create or edit anything in Jira.** Chaining into the next step is the developer's call, not this skill's.
9. **Never substitute a hand-read of the source for the graph**, and never report a repo as synced without the step-5 comparison.
10. **Never stop the whole run for one repo's trouble.** Every `--repo` is attempted; one that cannot be brought current is named as a stop and the run carries on with the rest.
11. **Never delete the graph artifacts as part of cleanup.** Step 3 clears scratch only: a rebuild that fails leaves the developer with the previous graph rather than none.

## Red flags — stop and start over

- "There's no `--repo`, so I'll ask which repos to sync"
- "I'll sync the two repos that already have graphs and skip the rest"
- "I'll wait for the `.understandignore` confirmation before continuing"
- "I'll pause here and ask the developer whether to proceed"
- "`--repo` names something that isn't in `.gitmodules`, so I'll ask which they meant"
- "The issue says backend, so `--repo BE` means `accountia-backend` — I'll map the prefixes myself"
- "I'll just pick `accountia-backend`, it's almost certainly that one"
- "The hashes already match, so the graph is current — I'll skip the update"
- "The graph is only a couple of commits behind, close enough"
- "I'll run repos one at a time to be safe"
- "I'll let `@understand` decide the path, it knows better"
- "Incremental would be much faster here, and it usually works"
- "I'll only run `--full` when the graph looks actually broken"
- "`--full` every time is wasteful — I'll check first"
- "The incremental path failed, so I'll ask the developer whether to do a full rebuild"
- "I'll leave the old `intermediate/` files, the rebuild will overwrite them anyway"
- "A previous run's `batch-*.json` files are still there, but they're harmless"
- "I'll clear `.ua/` completely — including the graph — to be safe"
- "The rebuild failed, so I'll hand-edit `meta.json` to match `HEAD`"
- "The rebuild failed, but the source is right there — I'll read it by hand"
- "The rebuild didn't land, but I'll mark that repo synced and flag it in the report"
- "I'll use another repo's graph, the repos are similar"
- "That repo has no `.ua/` yet, so I'll skip it"
- "The submodule has no checkout at all, so I'll skip that repo"
- "The fast-forward failed because the branch diverged, so I'll `--force` it"
- "I'll `reset --hard` to get the submodule onto the default branch"
- "The uncommitted changes are probably junk, I'll overwrite them"
- "I'll switch the superrepo's branch too, so everything lines up"
- "One repo failed, so I'll abort the whole run"
- "I'll write the result into `docs/refinement/` as a note for later"
- "Since the graphs are now current, I'll run `/refinement` straight away"
- "I'll update the submodule pointer in the superrepo to record the new commit"

All of these mean: reread the Hard Rules. The deliverable is an updated graph at the synced commit, for every repo attempted, nothing more.

## Steps

### 1. Resolve the repos — never by asking

List every submodule of the superrepo:

```bash
git -C <accountia-all> config --file .gitmodules --get-regexp path
```

- **No `--repo` → use all of them.** That is the whole list, in the order it appears. Do not filter it down and do not ask.
- **`--repo` given → use exactly those.** A value that does not appear in `.gitmodules` is a **named stop**: say which one and list what is available, then carry on with the rest. Do not map `BE` to the backend, do not pick the closest name, and do not ask — nobody is listening.
- The accountia-all root is the directory that contains `.gitmodules` — also the directory that contains `.claude/skills/refinement/` or `.opencode/skills/refinement/`; if the working directory already is it, that is it.
- A submodule directory that is missing or empty has no checkout yet: run `git -C <accountia-all> submodule update --init -- <repo>` once for it, then carry on into step 2 as usual. That is checkout setup, not a sync — the fetch, switch and fast-forward still have to happen — and it never applies to the other repos. If that init fails, stop that repo and name the error; the rest of the run continues.

### 2. Sync the code — per repo, without asking first

```bash
git -C <accountia-all>/<repo> fetch -q origin
b=$(git -C <accountia-all>/<repo> rev-parse --abbrev-ref origin/HEAD)
git -C <accountia-all>/<repo> switch -q "${b#origin/}"
git -C <accountia-all>/<repo> merge -q --ff-only "$b"
```

Use the repo's **remote default branch** (`origin/HEAD`), not a hardcoded `main` — the branch name is a fact to read, not to assume. If `origin/HEAD` cannot be read (the remote was not fetched, the symbolic ref is unset), stop that repo and name it; do not fall back to `main`, and do not ask.

- **Detached HEAD** (normal for submodules) or a **feature branch** → switching is the fix and is expected; submodules are routinely left wherever the last command put them.
- **The fetch fails** (no network, no credentials) → that repo cannot be synced: name it as a stop with the error and carry on with the other repos.
- **Uncommitted changes** → `git stash -u` first, sync, then record the stash entry (`git stash list`) in the report so it is not lost. **Leave it stashed — do not `pop` it**: the synced branch may conflict with their changes, and resolving that is their call. If you are unsure whether those changes are wanted at all, stop that repo and report rather than stashing. Their work outranks the sync.
- **The fast-forward fails because the branch has diverged** → **stop that repo and report**. Divergence means someone committed here deliberately. No rebase, no reset, no force. The remaining repos still run. If you stashed uncommitted work for this repo before syncing, report that stash entry with the stop, so it is not lost behind the failure.
- Do **not** switch branches of, or otherwise touch, the superrepo itself.

### 3. Dispatch parallel sub-agents — one per repo

For each repo that synced successfully in step 2, dispatch a **sub-agent** to handle steps 3–5 (clear scratch, update graph, verify). All sub-agents run concurrently.

Each sub-agent receives:
- The repo name and path (`<accountia-all>/<repo>`)
- The branch and commit it synced to
- The graph's `gitCommitHash` before the update (read from `.ua/meta.json` if it exists)

Each sub-agent must:

#### 3a. Preserve scratch for better incremental updates

**Do NOT delete scratch artifacts.** Preserving `.ua/intermediate/` and `.ua/tmp/` allows the incremental update (`@understand`) to reuse prior analysis and merge cleanly with existing batch data rather than rebuilding from zero. This improves incremental graph updates significantly.

- Leave `intermediate/`, `tmp/`, and any `.trash-*` untouched.
- Do **not** touch `knowledge-graph.json`, `meta.json`, `fingerprints.json`, `config.json`, or `.understandignore`.
- If `.ua/` (or `.understand-anything/`) does not exist, this is a first build — step 3b creates it.
- Record that scratch was preserved (not removed) for this repo.

#### 3b. Update the graph — incremental first, full as fallback

**First attempt: incremental update (no `--full`).**

```bash
# Invoke the understand skill for this repo (incremental)
# Call: skill: understand --repo <repo>
```

Run the understand skill against this repo (`skill: understand --repo <repo>`). Without `--full`, it analyzes only what has changed since the last graph and merges the result into the existing graph.

- **Answer its one prompt yourself.** A run pauses before scanning to ask about `.ua/.understandignore` — "review it, then confirm to continue". **Confirm and carry on.** The file is either already present or was just generated from the repo's `.gitignore`; reviewing it is the developer's choice and not what this run is for. This run has nobody to ask, so treating that pause as a stop would hang the job and leave every graph stale. You are the one the prompt is addressed to — treat it as answered and continue; do not wait for a reply that cannot come. If the file did not exist and the run generates a starter one, that is expected — let it, then continue.
- **Never let it stop to ask anything else either.** Any other prompt with a safe default gets the default and a line in the report.

**If the incremental path fails — fall back to full rebuild automatically and run all phases:**

```bash
# Invoke the understand skill for full rebuild
# Call: skill: understand --repo <repo> --full
```

`--full` forces a full rebuild, ignoring any existing graph. **When fallback occurs, automatically run all phases (Phase 1 scan through Phase 7 finalize) without waiting for confirmation.** All sub-agent phases (scan, batch, analyze, merge, review, architecture, tour, save) proceed sequentially and unconditionally.

`--full` forces a full rebuild, ignoring any existing graph, and it writes only into `.ua/` (or `.understand-anything/`) and leaves the working tree alone, so it is safe to run unprompted.

Fall back to `--full` when any of these occur:
- `@understand` returns an error or exits non-zero
- The incremental run declines to publish (e.g., cannot attribute files, validation gate fails)
- The incremental run publishes but `meta.json`'s `gitCommitHash` does not match `HEAD` (step 3c)
- The incremental run produces an incomplete graph (e.g., `knowledge-graph.json` is missing or malformed)

**Never ask the developer whether to fall back.** The fallback is unconditional — if incremental cannot produce a correct graph, run the full rebuild.

- **Say it up front.** Note which repo is rebuilding in full after an incremental failure, rather than silently spending the time.
- **Read the result, never steer it.** If a rebuild cannot publish, that is a failure for step 3c to report — not a cue to fall back further, to patch fingerprints or metadata, or to run `@understand` again without `--full`.

#### 3c. Verify the graph landed — per repo, before reporting

Read `$REPO/.ua/meta.json` and compare `gitCommitHash` against the repo's `HEAD`:

```bash
git -C <accountia-all>/<repo> rev-parse HEAD
node -p "require('<accountia-all>/<repo>/.ua/meta.json').gitCommitHash"
```

- **Match** → the update landed; this repo is done, and your report may claim it.
- **No match** → the update did not land where expected. **Stop for that repo and report both values** (HEAD and the graph's hash), name the blocker far enough for the developer to act on it — the tool's message, the file its parser could not attribute, the validation gate that would not clear — and the remedy (upgrade or patch the tool, or fix the source). No hand-editing `.ua/`, no other repo's graph, no reading the source by hand and calling it synced, no "I'll continue and note it".
- If `meta.json` is missing after the update, that is the same failure: the update did not publish. Report it the same way.

### 4. Collect results and report

Wait for all sub-agents to complete. Each sub-agent returns:
- Repo name
- Branch and commit it synced to
- Whether the sync moved it (by how many commits, or branch switch)
- Graph `gitCommitHash` before and after
- Which path was used (incremental / full fallback / stopped before update)
- Which scratch directories were cleared
- Any stash entry created
- If stopped: where it stopped and the blocker

Then write the final report:

Per repo, **in the output of this run** — there is no reader watching it live, so the report is the only record and must stand on its own:

| Repo | Branch | Commit | Sync moved it | Path taken | Graph `gitCommitHash` before | Graph `gitCommitHash` after | Result |
|---|---|---|---|---|---|---|---|
| `<repo>` | `<branch>` | `<sha>` | yes, +N commits / yes, switched from `<branch>` at `<sha>` / no, already current / — | incremental / full (incremental failed) / — | `<sha>` / `none` / `not reached` | `<sha>` / `—` | updated / rebuilt / stopped |

- "Before" is what `.ua/meta.json` held when you started (read it before step 3a clears scratch; `none` if there was no graph, `not reached` if the repo stopped in step 2). "After" is what step 3c verified.
- "Path taken" is `incremental` if the incremental path succeeded, `full (incremental failed)` if the fallback was used, or `—` if the repo stopped before step 3b.
- Scratch cleared: name the repo and which directories were removed (or "nothing to clear").
- When a repo stopped, name where it stopped and the blocker. If it got as far as step 3c, also give both commit values (HEAD and the graph's hash) and what the developer needs to do next.
- When you stashed uncommitted work (step 2), name the repo and the stash entry, so the developer can restore it later.
- An invalid `--repo` value that is not a submodule gets no table row (it is not a repo): list those names separately under the table, marked `not a submodule`, together with the available names from step 1.
- End with a one-line tally: repos attempted, updated (incremental), rebuilt (full fallback), and stopped. Never leave the report implying a repo succeeded when it did not.
- This skill writes **no files at all** — the report is the output of the run.

## Why it is built this way

**Unattended by default.** The skill is meant to be fired by a scheduler with no one watching, so its two natural blocking points are neutralized: `@understand`'s `.understandignore` confirmation is answered by proceeding rather than by waiting, and any incremental-to-full fallback decision is made automatically rather than by asking. A job that hangs produces no error and no updated graph — the worst possible outcome, because it looks like nothing happened at all.

**Incremental first, full as fallback.** Incremental updates are faster and sufficient for most syncs — a submodule that has only moved forward since the last graph usually needs only a delta analysis. The incremental path is tried first to save time. If it fails for any reason, the full rebuild is the safety net: it is slower but always correct. The developer does not need to be consulted — the fallback is automatic and unconditional.

**Parallel sub-agents per repo.** Processing repos sequentially is slow — a full sync of N repos takes N times as long as one repo. Dispatching each repo as an independent sub-agent means all repos are analyzed concurrently, so the total time is roughly the time of the slowest single repo. A sub-agent failure in one repo does not affect the others.

**All repos, not a hand-listed few.** A scheduled sync that only covered the repos someone remembered to name would quietly rot the moment a new submodule appears. Defaulting to every submodule means the graph set tracks the repo set, and `--repo` remains as a manual narrowing tool only.

**Scratch is cleared, artifacts are not.** A run merges `batch-*.json` from `.ua/intermediate/`; leftovers from an earlier run that died part-way would compete with the fresh analysis for the same files. Clearing `intermediate/`, `tmp/`, and orphaned `.trash-*` removes that hazard while leaving the graph artifacts for the update to overwrite — and for the developer to keep, if the update fails.

**Code first, then graph.** A graph rebuilt against a branch that has since moved is stale the moment it is published, and the step-3c comparison would then pass against the wrong commit. Step 2 makes `HEAD` equal `origin/<default>`, which is why comparing against local `HEAD` is correct here — this is not a standalone clone where `HEAD` may be days old.

**A repo that will not sync is a named stop, not the end of the run.** One repo's divergence, missing graph, or absent credentials must not cost the other repos their update — so the run carries on and the failure is reported precisely, rather than aborting everything behind the first problem.

## What NOT to do

- Don't ask the developer anything, and don't wait on any prompt — the run is unattended.
- Don't wait for `@understand`'s `.understandignore` confirmation; confirm and carry on.
- Don't require `--repo`; with none given, sync every submodule.
- Don't map `BE` / `FE` / `QC` onto repo names, and don't ask what an unknown `--repo` value meant — report it as a stop.
- Don't run repos sequentially — dispatch them as parallel sub-agents.
- Don't skip the incremental path and jump straight to `--full` without trying incremental first.
- Don't ask the developer whether to fall back to `--full` when incremental fails — just do it.
- Don't run `@understand --full` as the default; it is the fallback, not the first choice.
- Don't delete `knowledge-graph.json`, `meta.json`, `fingerprints.json`, `config.json`, or `.understandignore` while clearing scratch.
- Don't carry stale `intermediate/` or `batch-*.json` files into an update.
- Don't hand-edit `.ua/`, `meta.json`, or any graph file to make the hash match.
- Don't rebase, reset, or force a submodule, and don't discard uncommitted changes instead of stashing them.
- Don't switch branches of the superrepo, and don't move the superproject's submodule pointers.
- Don't abort the whole run because one repo failed.
- Don't report a repo as synced without the step-3c comparison, and don't leave a repo's result out of the report.
- Don't read the source by hand and present that as a synced graph.
- Don't chain into `/refinement`, `/refinement:create`, or any Jira write — the updated graphs are the deliverable, and the developer runs the next step.
- Don't write files. Not sub-task files, not a log, not a report. The report is the output of the run.

## Output

Report back per repo, using the step-4 table: the branch it ended up on and the commit it reached, whether the sync moved it (by how many commits, or that it switched branches), which path was taken (incremental / full fallback), the graph's `gitCommitHash` before and after (`none` / `not reached` where they apply), and whether the update landed. Name which scratch directories you cleared, any stash you left behind, and any stopped repo with where it stopped and the blocker — adding both commit values only when it got as far as step 3c. Close with the attempted / updated (incremental) / rebuilt (full fallback) / stopped tally.
