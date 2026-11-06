---
name: review-code-review-story
description: Review a Jira story's FE and BE merge requests against the story, its sub-tickets and its [QC] scenarios, together across repos when every side has an MR; writes a new -v<n> report to workspace/docs/reviews/ that sums up what changed since earlier versions, has the user review it in Plannotator, and optionally replies on the MRs.
disable-model-invocation: true
---

# Review code review: story

Runs `/code-review` for a whole Jira **story**. The story's **dev sub-tasks** (`[BE]`, `[FE]`) are built in separate repos, and each carries its own merge request. Each MR is checked out into a temporary **review worktree** and reviewed on the **Standards**, **Spec** and **QA** axes. When every dev sub-task has an MR, the MRs are reviewed **together**, with a fourth **Contract** axis that reads both sides of every API the FE and BE share. The story's `[QC]` scenarios always drive the QA axis.

Along the way the skill collects the **open questions** waiting on the reviewer, proposes an answer to each in the report, and the user settles them while reviewing the report in Plannotator. The report is always written to a file; answers and the report go to the MRs only on request. It finishes when the report is written, everything is published where the user chose, and every review worktree is removed. The review reports findings only; the code stays as it is.

`$WS` is the `workspace` directory: the nearest ancestor of the current directory that contains `workspace/` (today `D:\projects\proj-accountia\workspace`). A module's main checkout is `$WS/<module>/main/`; its worktrees sit beside it at `$WS/<module>/<worktree>/`. Run every git command with `git -C <path>`, since the shell's working directory resets outside the session's directories.

## Dependencies

This skill reads sibling skills: `code-review` (mattpocock/skills), `jira-ticket`, `accountia-conventions`, `review-loop` (Accountia). Before anything else, check that each has a `SKILL.md` in a folder beside this skill's own. For each missing one, ask the user, then install it with `npx skills add <source> --skill <name> -a claude-code -y`, adding `-g` when this skill sits under the home directory. The Accountia source is the `source` recorded for this skill in `skills-lock.json`; if none is recorded, ask for it.

## Input

`/review-code-review-story <story>`

- **Story:** a Jira key (`ACC-8439`) or browse URL; extract the key from a URL. Without one, ask.

## Atlassian calls

Read every ticket as [`../jira-ticket/SKILL.md`](../jira-ticket/SKILL.md) describes, using its Atlassian calls: the issue, all comments, the parent, and every linked Confluence page. Jira is read only here.

## 1. Map the story

Read the story. Then sort its sub-tasks and issue links by the summary prefix:

| Prefix | Role | Module |
|---|---|---|
| `[BE]` | dev sub-task | `accountia-backend` |
| `[FE]` | dev sub-task | `accountia-frontend` |
| `[QC]` or `[QA]` | **QA ticket** | none |

A sub-task with any other prefix, or with two dev prefixes: ask the user which module it changes. More than one QA ticket: ask which to use.

For each dev sub-task, find its **open MRs** in its module: run `glab mr list --per-page 100 --output json` in `$WS/<module>/main`, and keep the MRs whose title, description or source branch contains the sub-task key, compared case-insensitively. More than one open MR for one sub-task: ask the user which to review.

Done when every sub-task has a role, and every dev sub-task has exactly one MR or is marked **no MR**.

## 2. Pick the mode

- **Joint:** every dev sub-task has an MR. All MRs are reviewed together.
- **Single:** some dev sub-tasks have an MR and others do not. Each MR is reviewed alone, against its own sub-task, as a separate **pass** of steps 3 to 5. The report lists every sub-task marked no MR.
- **No MR:** stop. Print every dev sub-task with its key and summary, and say none has an open MR.

A story with a single dev sub-task that has an MR runs in Joint mode with one repo, and the Contract axis says "one side only".

Tell the user the mode and the MRs in one line before going on.

## 3. Check out the MRs

For each MR in scope:

1. **Read the MR:** `glab mr view <iid> --comments` in `$WS/<module>/main` gives the title, description, discussions, source branch, target branch, and iid.
2. **Check it out** into the review worktree `$WS/<module>/review-<sub-task key>-mr<iid>`, detached:
   `git -C "$WS/<module>/main" fetch origin merge-requests/<iid>/head <target branch>`, then
   `git -C "$WS/<module>/main" worktree add --detach "$WS/<module>/review-<sub-task key>-mr<iid>" FETCH_HEAD`.
   If that path already exists, remove it first with `git worktree remove --force`, then add it again.

The review worktrees are the only repos under review.

Done when every review worktree's HEAD equals its MR's latest commit SHA.

## 4. Gather the sources

1. **Spec:** the story together with every dev sub-task in scope (a Single pass: the story and that pass's sub-task). The story's comments override older ticket text. A conflict between the comments and the ticket text, or between the FE and BE sub-tasks, is **spec drift**. Each MR's description and discussions are context for the Spec axis; the tickets stay the spec.
2. **QA ticket:** read the one from step 1. List every **scenario** with its preconditions, steps and expected result, numbered in its own order.
3. **Standards:** the [development conventions](../accountia-conventions/conventions.md), and for each module the per-stack Confluence page they link (Angular for `accountia-frontend`, Java and Spring Boot plus Database and API Design for `accountia-backend`). Add any standards file the repo itself documents.
4. **Diffs:** for each review worktree, run `git -C <repo> fetch origin`, then capture `git -C <repo> diff origin/<target branch>...HEAD` and `git -C <repo> log origin/<target branch>..HEAD --oneline`. Confirm the fixed point `origin/<target branch>` resolves and the diff is non-empty in each repo.
5. **Open questions:** the **reviewer** is the user running this skill: their GitLab username (`glab api user`, field `username`) and their Jira account (`atlassianUserInfo`). An open question is a comment in the story, a dev sub-task or an MR (its description or its discussions) that asks the reviewer to decide, confirm, approve, or act (an @-mention of them, or a question to the MR's reviewers), with no later reply from the reviewer in the same thread. For each, record: who asked, when, the source (Jira comment, MR description, or MR discussion ID and note URL), the question in one sentence, and the options the asker offered with their recommendation.
6. **Earlier versions:** every file in `$WS/docs/reviews/` whose name contains `-<story key>-` is an earlier **version** of this review, whatever its date or suffix. When any exist, read the latest one in full: its findings, its open questions, its next actions, and the HEAD SHA of every MR in its header. For each repo whose HEAD has moved since then, also capture `git -C <repo> diff <previous SHA>..HEAD` and `git -C <repo> log <previous SHA>..HEAD --oneline`. Collect everything that changed outside the code since that version: new MR notes and discussions, new or edited MR titles and descriptions, and new Jira comments.

Done when the spec, the QA scenarios (if any), every standards source, a non-empty diff per repo, the open questions (possibly none), and the latest earlier version with its deltas (when one exists) are in hand.

## 5. Run the review

Read [`../code-review/SKILL.md`](../code-review/SKILL.md) and follow its process from step 4, with these overrides:

- **Sources.** Steps 1 to 4 above replace its steps 1 to 3. The tracker is Jira, and every source is already gathered. Keep its smell baseline, pasted in full into the Standards prompt.
- **Repos.** Each sub-agent gets every repo's path, diff command and commit list in the pass.
- **Open questions.** Give the Spec sub-agent the open-question list. Work the author proposed and is waiting on the reviewer to approve counts as **pending**, reported under its own label, separate from deviations.
- **Spec drift.** The Spec sub-agent reports spec drift under its own heading: which source the code follows, and where the sources disagree.
- **QA axis.** Spawn a third sub-agent in parallel with the other two. Give it the diff commands, the numbered scenario list, and the spec. Brief: "For each scenario, give a verdict: *covered* (code handles it and a test exercises it), *untested* (code handles it, no test), *missing* (no code path handles it), *conflict* (the code produces a different result than the scenario expects), or *n/a* (the other module's side only). Quote the scenario and cite file:line for each verdict. Then list scenarios that contradict the spec. Under 500 words." With no QA ticket, skip it.
- **Contract axis (Joint mode).** Spawn a fourth sub-agent in parallel. Give it every repo's path and diff command, and the spec. Brief: "Compare what the BE serves and accepts with what the FE sends and reads, for every endpoint, enum, error code and payload field either diff touches. For each, give a verdict: *match*, *mismatch* (cite both sides file:line, and say which side fails at runtime and how), or *one-sided* (changed on one side only, cite it). Read the code in both review worktrees; take nothing from summaries. Under 450 words."
- **Aggregate.** Keep each axis under its own heading: `## Standards`, `## Spec`, `## Contract` (Joint mode), `## QA scenarios`. Without a QA ticket, the QA heading says "no QA ticket". Inside each heading, label every finding with its module.

Done when every axis has reported for every pass, the Contract axis covers every shared value either diff touches, and every QA scenario has exactly one verdict.

## 6. Write the report

Write one new report to `$WS/docs/reviews/<DD-MM-YYYY>-<story key>-<slug>-v<n>.md`. The date is today; the slug is the story summary in lowercase, words joined by hyphens, with any `[..]` prefix dropped, cut short if long. The version `<n>` is one more than the number of earlier versions from step 4, and higher than every `-v<n>` already used for this story: the first review is `-v1`. Every run adds a version; earlier versions stay as they are. Create `$WS/docs/reviews/` if it does not exist.

The report starts with:

```
# Code review: <story key> <story summary> (v<n>)

- Story: <story key> (<browse URL>)
- Version: v<n>; previous: <file name of the latest earlier version>, or none
- Mode: joint | single
- Sub-tasks: one line per dev sub-task: <key> <summary>, MR !<iid> (<MR URL>) @ <HEAD short SHA>, or no MR
- QA ticket: <QA key> (<browse URL>), or none
- Fixed point: origin/<target branch> per repo
- Commits: the commit list per repo
```

When earlier versions exist, follow the header with `## Changes since earlier versions`:

1. **Versions:** a table with one row per version, oldest first: version, file name, date, and the HEAD short SHA per MR.
2. **What moved:** per MR, the commits added since the previous version (or "no new commits"), each with one line on what it changes; then every MR title, description or discussion change, and every new Jira comment.
3. **Fixed:** every finding, open question and next action of the previous version that is now resolved, with the evidence (commit, file:line, note or comment).
4. **Partly fixed:** the same, saying what remains.
5. **Still open:** the rest of the previous findings, one line each.
6. **New:** findings that first appear in this version.

Every finding and open question of the previous version lands in exactly one of Fixed, Partly fixed or Still open. In the axis sections, tag each finding **resolved**, **partly resolved**, **open** or **new** to match.

Then the axis sections from step 5. In Single mode, wrap each pass's sections in one `## <sub-task key> <module>` section.

When step 4 found open questions, add `## Open questions`. It opens with `### Thread so far`, one per thread that holds an open question: a dated, numbered recap of who said what, in order, naming every option by its label and quoting the reviewer's own earlier replies, so the reviewer can answer without rereading the thread. Then one numbered entry per question:

```
### Q<n>. <the question in one sentence>
- Asked by: <asker>, <date>, <source: Jira comment, MR !<iid> description, or MR !<iid> discussion <discussion id> (<note URL>)>
- Options: <the asker's options and recommendation>
- Answer: <proposed answer, grounded in the review findings> — <reason in one line>
```

Then `## Next actions`: every action the findings and the proposed answers call for, grouped by owner (the reviewer first, then each MR author, then anyone else named, then the tickets), numbered across groups. Each action names its concrete target (file, setting, ticket, MR or thread).

Last comes the summary line: the finding count per axis, the worst finding within each axis (in Joint mode, the worst Contract mismatch), and the open-question count. With earlier versions, add the count fixed, partly fixed, still open and new since the previous version.

Done when the file holds every axis section for the mode, a recap of every thread holding an open question, every open question with a proposed answer, the next actions, and the summary line; and, with earlier versions, every finding and open question of the previous version sits in exactly one of Fixed, Partly fixed or Still open.

## 7. Review the report

Run the [review loop](../review-loop/SKILL.md) on the report file. The user answers the open questions through their annotations: write each answer they give into its `Answer:` line, replacing the proposal, and mark a question they set aside as `Answer: skipped`. Bring `## Next actions` in line with every changed answer.

Done when the user approves. A closed session ends the skill there: go straight to the clean-up in step 9, and print the report path.

## 8. Reply on the MRs

Skip this step when no open question with an answer comes from an MR discussion.

Print those questions again, each as its question and its final `Answer:` from the approved report. Then ask the user with AskUserQuestion whether to reply under those threads.

- **Yes:** post each answer as a reply in its own MR's discussion with `glab api --method POST projects/<url-encoded project>/merge_requests/<iid>/discussions/<discussion id>/notes -f body="<answer>"`, add a `- Reply: <note URL>` line to that question in the report, and mark the matching reply action in `## Next actions` as done.
- **No:** the answers stay in the report only.

Done when every MR answer carries a `Reply:` line, or the user chose No.

## 9. Publish and clean up

**Publish.** Ask the user with AskUserQuestion where the report goes:

- **Local only:** the report file is the result.
- **GitLab:** post the report on every MR in scope with `glab mr note <iid> -R <project> --message "<report>"`, then add one `- Posted: <URL>` line per MR under the report header.

**Clean up.** Remove every review worktree from step 3 with `git -C "$WS/<module>/main" worktree remove --force "$WS/<module>/review-<sub-task key>-mr<iid>"`.

Done when the report sits where the user chose and no review worktree remains. Print the report path, every posted URL, and the summary line.
