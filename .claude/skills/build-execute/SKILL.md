---
name: build-execute
description: Execute a ticket's implementation plans from workspace/docs/build/plans/<KEY>/ with superpowers, in worktrees under workspace/<module>/.
disable-model-invocation: true
---

# Build execute

Runs the **plans** that `/build-plan` wrote for one ticket through superpowers, from the first task to a finished branch. Each module the plans change gets one **worktree**, and every plan for that module runs in it. The skill finishes when `superpowers:finishing-a-development-branch` has run for every module.

`$WS` is the `workspace` directory: the nearest ancestor of the current directory that contains `workspace/` (today `D:\projects\proj-accountia\workspace`). A module's main checkout is `$WS/<module>/main/` (e.g. `$WS/accountia-backend/main/`). Its worktrees sit beside it, at `$WS/<module>/<worktree>/`.

The shell's working directory resets when it leaves the session's working directories. Run every command with absolute paths or `git -C <path>`.

## 1. Find the plans

**Input:** one of the following. If you get none, or the input resolves to no plan file, ask for one.

- **A ticket key** (`ACC-1234`) or a browse URL. Extract the key from a URL. The plan folder is `$WS/docs/build/plans/<KEY>/`, and the plans are its `plan-<NN>-<module>-<slug>.md` files, run in number order.
- **A path to a plan file.** Run only that plan. Its folder is the plan folder.

For each plan, read its header and record its **module**. The module comes from the `Repository root` line (`$WS/<module>/main`). If the plan has no such line, take it from the `<module>` part of the file name.

From the `Ticket:` line of `<plan folder>/design.md`, take the **ticket key**. Then fetch the ticket with `getJiraIssue` (`cloudId` `genieitsoultions.atlassian.net`) to get its **title** and issue type. If the ticket has no Jira key, ask the user for the branch name.

Done when every plan has a module, and the ticket has a key, a title and a type.

## 2. Choose the executor

Ask the user once, with AskUserQuestion, which executor runs every plan:

- **Subagent-driven:** `superpowers:subagent-driven-development`. A fresh implementer and a reviewer for each task, then a whole-branch review.
- **Inline:** `superpowers:executing-plans`. You implement every task yourself, then one fresh reviewer checks the whole branch.

Put your recommendation first. Give its reason in one sentence drawn from the plans: how much the tasks depend on each other's interfaces, how many tasks there are, and what a shipped mistake would cost.

Done when the user has chosen.

## 3. Create the worktrees

Read the Git section of the [development conventions](../../rules/conventions.md). Then name the work:

- **Case type:** one of the conventions' eight types. Use `feat` for a Story and `fix` for a Bug. For any other ticket type, use the type that matches the work.
- **Slug:** the ticket title in lowercase, with words joined by hyphens. Cut it short if it is long.
- **Branch:** `<case-type>/<KEY>-<slug>`. Every module uses the same branch name.
- **Worktree:** `$WS/<module>/<KEY>-<slug>`, the branch name without its case-type prefix.

For each module the plans change:

1. **Reuse** the worktree if its path is already a worktree on that branch (check with `git -C "$WS/<module>/main" worktree list`).
2. **Otherwise create it** from the main checkout:
   `git -C "$WS/<module>/main" fetch origin`, then
   `git -C "$WS/<module>/main" worktree add "$WS/<module>/<KEY>-<slug>" -b <branch> origin/main`.
3. **Set it up:** run Step 2 (project setup) and Step 3 (baseline tests) of `superpowers:using-git-worktrees` inside the worktree.

This step replaces Steps 0 and 1 of `using-git-worktrees`. Invoking this skill is the user's consent, and the path above is where the worktree goes.

Done when every module has a worktree on its branch, and its baseline tests have run. Report failing baseline tests as `using-git-worktrees` describes.

## 4. Execute the plans

Take the plans in number order. For each one, invoke the executor chosen in step 2 and follow it, with these overrides:

- **Worktree.** Setup's worktree step is already done: the plan runs in its module's worktree from step 3. The plan's paths are relative to `$WS/<module>/main`, so resolve them against the worktree instead. Every subagent gets the worktree path as its repository root.
- **Conventions.** Commit messages follow `<case-type>: <KEY>-<Description>`, using the case type from step 3. Test names follow `<method>_when_<scenario>_then_<outcome>`.
- **Finish.** Run `superpowers:finishing-a-development-branch` once per module, after that module's last plan. Recommend option 2, since changes reach trunk only through a merge request. The remote is GitLab, so open the merge request with `glab mr create`, titled `<KEY>-<slug>`, with a description that references the ticket.
- **Continuity.** Go straight from one plan to the next. The executor's four stop conditions are the only reasons to stop.

Done when every plan's ledger has a `complete` line for each of its tasks, every plan has had its final review, and every module has been through `finishing-a-development-branch`.

## 5. Report

Print, for each module, the worktree path, the branch, and the outcome of `finishing-a-development-branch` (with the merge request URL when there is one). Then print every plan's "Rulings I made" and "Deferred minors", grouped by plan.
