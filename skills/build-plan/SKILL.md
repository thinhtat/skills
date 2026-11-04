---
name: build-plan
description: Brainstorm a Jira ticket into implementation plans under workspace/docs/build/plans/<KEY>/, reviewed in Plannotator.
disable-model-invocation: true
---

# Build plan

Turns one Jira **ticket** into a **design** with `superpowers:brainstorming`, then into **implementation plans** with `superpowers:writing-plans`. The ticket is the only source of requirements: every requirement, rule and value in the design and plans traces to the ticket's content. The skill runs **unattended** from the ticket key to the review: the user's first input after the key is the plan review. It finishes when the user has approved or closed that review.

`$WS` is the `workspace` directory: the nearest ancestor of the current directory that contains `workspace/` (today `D:\projects\proj-accountia\workspace`). The **plan folder** is `$WS/docs/build/plans/<KEY>/`; everything this skill writes goes there, and every file stays uncommitted.

The **code** of each module lives in its main worktree, `$WS/<module>/main/` (e.g. `$WS/accountia-backend/main/`). Read it with CodeGraph when the worktree has a `.codegraph/` index.

## Dependencies

This skill reads sibling skills: `jira-ticket` (Accountia), `accountia-conventions` (Accountia), `review-loop` (Accountia). Before anything else, check that each has a `SKILL.md` in a folder beside this skill's own. For each missing one, ask the user, then install it with `npx skills add <source> --skill <name> -a claude-code -y`, adding `-g` when this skill sits under the home directory. The Accountia source is the `source` recorded for this skill in `skills-lock.json`; if none is recorded, ask for it.

## 1. Read the ticket

**Input:** a ticket key (`ACC-1234`) or a browse URL; extract the key from a URL. If none is given, ask for one.

Read the ticket as [`../jira-ticket/SKILL.md`](../jira-ticket/SKILL.md) describes: the issue, all comments, the parent, every linked Confluence page, plus the summary and description of each sub-task. Jira is read only; the ticket's status, assignee and comments stay as they are.

If the plan folder already exists, overwrite its files.

Then read the [development conventions](../accountia-conventions/conventions.md) in full: coding principles, error handling, security, testing, and Git naming for branches and commits. For each module the ticket touches, also fetch the per-stack Confluence page the conventions link (Angular, Java and Spring Boot, Database, API Design).

Done when every source above has been read in full.

## 2. Brainstorm the design

Invoke `superpowers:brainstorming` and follow it, with these overrides:

- **Description.** The ticket content is the full description; the conversation phase is skipped. Where the ticket leaves something open, make the call yourself and mark it in the design as an **assumption**, with the reason.
- **Codebase.** Explore the code of the modules the ticket touches, and build the design on the patterns it already uses.
- **Conventions.** The design follows the conventions read in step 1, such as the 3-layer backend architecture and the security baseline. Where the code and the conventions disagree, or a convention is listed under its known discrepancies, record it as an assumption and don't resolve it silently.
- **Size.** The ticket is a project with a written design.
- **Builder check.** Run it; settle every question it raises as answered-from-the-ticket or as an assumption.
- **Where it goes.** `<plan folder>/design.md`. Its first line under the title is `Ticket: <KEY> (<browse URL>)`.
- **Approval.** The plan review of step 4 is the approval; go straight on to step 3.

Done when `design.md` covers every acceptance criterion of the ticket, and every assumption is marked.

## 3. Write the plans

Invoke `superpowers:writing-plans` and follow it, with these overrides:

- **Spec.** `design.md` is the spec each plan names in its header.
- **Codebase.** Every file, signature and test a plan names exists in the code today, or the plan creates it.
- **Conventions.** Every plan follows the conventions read in step 1. Its branch name is `<case-type>/<KEY>-<slug>`, and every commit step uses the message `<case-type>: <KEY>-<Description>`. Test names follow `<method>_when_<scenario>_then_<outcome>`, and the tasks include the unit, integration and contract tests the conventions require.
- **Split.** One plan per module the design changes, in dependency order (a backend API before the frontend that calls it).
- **Where they go.** `<plan folder>/plan-<NN>-<module>-<slug>.md`, numbered from `01` in that order.
- **Handoff.** The review of step 4 replaces its execution handoff.

Done when every acceptance criterion of the ticket is owned by a task in some plan, every plan follows the conventions, and its self-review has passed on every plan.

## 4. Review the plans

Run the [review loop](../review-loop/SKILL.md) on the plan files together, in number order (`plannotator annotate <plan-01> <plan-02> …`). Re-check the step-3 completion criterion after each round of edits.

On approval, print every plan path and the assumptions recorded in `design.md`.
