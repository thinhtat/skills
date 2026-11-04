---
name: review-code-review
description: Review a ticket's branch or a GitLab MR against its Jira spec, the team conventions, and an optional QA ticket's scenarios; writes the report to workspace/docs/reviews/, has the user review it and answer open questions in Plannotator, and optionally replies on the MR.
disable-model-invocation: true
---

# Review code review

Runs `/code-review` for one Jira ticket: the **Standards** and **Spec** axes, plus a third **QA** axis when a QA ticket lists the scenarios to check. The code under review is either your own branch in a local worktree, or someone else's **merge request** checked out into a temporary review worktree. Along the way it collects the **open questions** waiting on the reviewer, proposes an answer to each in the report, and the user settles them while reviewing the report in Plannotator. The report is always written to a file; answers and the report go to the MR only on request. It finishes when the report is written, everything is published where the user chose, and the review worktree is removed. The review reports findings only; the code stays as it is.

`$WS` is the `workspace` directory: the nearest ancestor of the current directory that contains `workspace/` (today `D:\projects\proj-accountia\workspace`). A module's main checkout is `$WS/<module>/main/`; its worktrees sit beside it at `$WS/<module>/<worktree>/`. Run every git command with `git -C <path>`, since the shell's working directory resets outside the session's directories.

## Input

`/review-code-review [<ticket>] [--mr <MR>] [--qa <QA ticket>] [--base <fixed point>] [--repo <path>]`

Give a ticket, an MR, or both.

- **Ticket:** a key (`ACC-1234`) or browse URL; extract the key from a URL. Without one, take it from the MR title (`[KEY]-[slug]`), else from the branch name (`<case-type>/<KEY>-<slug>`), else ask.
- **MR:** a GitLab MR URL or `!<iid>`. With a bare iid, the module comes from `--repo` or the current directory's repo; else ask.
- **QA ticket:** optional, a key or browse URL.
- **Fixed point:** defaults to `origin/<target branch>` for an MR, else `origin/main`.
- **Repo:** ignored with an MR. Otherwise defaults to every worktree matching `$WS/*/<KEY>-*`, plus the current directory when its branch carries the key. If none matches, ask for the path.

## Atlassian calls

Pass `cloudId` `genieitsoultions.atlassian.net`. Read a ticket as step 1 of [`../start-ticket/SKILL.md`](../start-ticket/SKILL.md) describes: the issue, all comments, the parent, and every linked Confluence page. Jira is read only here.

## 1. Check out the MR

Skip this step without `--mr`.

1. **Read the MR:** `glab mr view <MR> --comments -R <project>` gives the title, description, discussions, source branch, target branch, and iid. The **module** is the `$WS/<module>` whose `main` checkout has an `origin` pointing at the MR's project.
2. **Check it out** into the **review worktree** `$WS/<module>/review-<KEY>-mr<iid>`, detached:
   `git -C "$WS/<module>/main" fetch origin merge-requests/<iid>/head <target branch>`, then
   `git -C "$WS/<module>/main" worktree add --detach "$WS/<module>/review-<KEY>-mr<iid>" FETCH_HEAD`.
   If that path already exists, remove it first with `git worktree remove --force`, then add it again.
3. The review worktree is the only repo under review.

Done when the review worktree's HEAD equals the MR's latest commit SHA.

## 2. Gather the sources

1. **Spec:** read the ticket. Its sub-tasks stay outside the spec, except a QA ticket chosen below. With an MR, its description and discussions are context for the Spec axis; the ticket stays the spec.
2. **QA ticket:** read it when `--qa` names one. Without `--qa`, look among the ticket's sub-tasks and issue links for a summary starting with `[QC]` or `[QA]`; when you find one, ask the user whether to use it. From the QA ticket, list every **scenario** with its preconditions, steps and expected result, numbered in its own order.
3. **Standards:** the [development conventions](../../rules/conventions.md), and for each module the per-stack Confluence page they link (Angular for `accountia-frontend`, Java and Spring Boot plus Database and API Design for `accountia-backend`). Add any standards file the repo itself documents.
4. **Diffs:** for each repo, run `git -C <repo> fetch origin`, then capture `git -C <repo> diff <fixed point>...HEAD` and `git -C <repo> log <fixed point>..HEAD --oneline`. Confirm the fixed point resolves and the diff is non-empty in each repo.
5. **MR for a local branch:** without `--mr`, look up an open MR with `glab mr list --source-branch <branch>` in each repo. Read its discussions as in step 1.
6. **Open questions:** the **reviewer** is the user running this skill: their GitLab username (`glab api user`, field `username`) and their Jira account (`atlassianUserInfo`). An open question is a comment in the ticket or the MR discussions that asks the reviewer to decide, confirm, approve, or act (an @-mention of them, or a question to the MR's reviewers), with no later reply from the reviewer in the same thread. For each, record: who asked, when, the source (Jira comment, or MR discussion ID and note URL), the question in one sentence, and the options the asker offered with their recommendation.

Done when the spec, the QA scenarios (if any), every standards source, a non-empty diff per repo, and the open questions (possibly none) are in hand.

## 3. Run the review

Read [`../code-review/SKILL.md`](../code-review/SKILL.md) and follow its process from step 4, with these overrides:

- **Sources.** Steps 1–2 above replace its steps 1–3. The tracker is Jira, and every source is already gathered. Keep its smell baseline, pasted in full into the Standards prompt.
- **Several repos.** Each sub-agent gets every repo's path, diff command and commit list.
- **Open questions.** Give the Spec sub-agent the open-question list. Work the author proposed and is waiting on the reviewer to approve counts as **pending**, reported under its own label, separate from deviations.
- **QA axis.** When the QA ticket exists, spawn a third sub-agent in parallel with the other two. Give it the diff commands, the numbered scenario list, and the spec. Brief: "For each scenario, give a verdict: *covered* (code handles it and a test exercises it), *untested* (code handles it, no test), *missing* (no code path handles it), or *conflict* (the code produces a different result than the scenario expects). Quote the scenario and cite file:line for each verdict. Then list scenarios that contradict the spec. Under 500 words."
- **Aggregate.** Keep each axis under its own heading: `## Standards`, `## Spec`, `## QA scenarios`. Without a QA ticket, the QA heading says "no QA ticket".

Done when every axis has reported, and every QA scenario has exactly one verdict.

## 4. Write the report

Write the report to `$WS/docs/reviews/<DD-MM-YYYY>-<KEY>-<slug>.md`. The date is today; the slug is the ticket summary in lowercase, words joined by hyphens, cut short if long. Create `$WS/docs/reviews/` if it does not exist. If the file exists, ask whether to overwrite it or add a `-2` suffix.

The report starts with:

```
# Code review: <KEY> <ticket summary>

- Ticket: <KEY> (<browse URL>)
- MR: !<iid> (<MR URL>), or none
- QA ticket: <QA KEY> (<browse URL>), or none
- Fixed point: <fixed point>
- Repos: <module> @ <HEAD short SHA>, one per repo
- Commits: the commit list per repo
```

Then the three axis sections from step 3. When step 2 found open questions, add `## Open questions`. It opens with `### Thread so far`, one per thread that holds an open question: a dated, numbered recap of who said what, in order, naming every option by its label and quoting the reviewer's own earlier replies, so the reviewer can answer without rereading the thread. Then one numbered entry per question:

```
### Q<n>. <the question in one sentence>
- Asked by: <asker>, <date>, <source: Jira comment, or MR discussion <discussion id> (<note URL>)>
- Options: <the asker's options and recommendation>
- Answer: <proposed answer, grounded in the review findings> — <reason in one line>
```

Then `## Next actions`: every action the findings and the proposed answers call for, grouped by owner (the reviewer first, then the MR author, then anyone else named, then the ticket), numbered across groups. Each action names its concrete target (file, setting, ticket, or thread).

Last comes the summary line: the finding count per axis, the worst finding within each axis, and the open-question count.

Done when the file holds every axis section, a recap of every thread holding an open question, every open question with a proposed answer, the next actions, and the summary line.

## 5. Review the report

Run the [review loop](../../shared/review-loop.md) on the report file. The user answers the open questions through their annotations: write each answer they give into its `Answer:` line, replacing the proposal, and mark a question they set aside as `Answer: skipped`. Bring `## Next actions` in line with every changed answer.

Done when the user approves. A closed session ends the skill there: go straight to the clean-up in step 7, and print the report path.

## 6. Reply on the MR

Skip this step when no open question with an answer comes from an MR discussion.

Print those questions again, each as its question and its final `Answer:` from the approved report. Then ask the user with AskUserQuestion whether to reply under those threads on the MR.

- **Yes:** post each answer as a reply in its discussion with `glab api --method POST projects/<url-encoded project>/merge_requests/<iid>/discussions/<discussion id>/notes -f body="<answer>"`, add a `- Reply: <note URL>` line to that question in the report, and mark the matching reply action in `## Next actions` as done.
- **No:** the answers stay in the report only.

Done when every MR answer carries a `Reply:` line, or the user chose No.

## 7. Publish and clean up

**Publish.** When the review has an MR (from `--mr` or step 2), ask the user with AskUserQuestion where the report goes:

- **Local only:** the report file is the result.
- **GitLab:** post the report on the MR with `glab mr note <iid> -R <project> --message "<report>"`, then add the note's URL as a `- Posted: <URL>` line under the report header.

Without an MR, the report stays local.

**Clean up.** Remove the review worktree from step 1 with `git -C "$WS/<module>/main" worktree remove --force "$WS/<module>/review-<KEY>-mr<iid>"`.

Done when the report sits where the user chose and no review worktree remains. Print the report path, every posted URL, and the summary line.
