---
name: start-ticket
description: Kick off a Jira ticket: fetch its spec (issue, parent, comments, linked Confluence pages), flag spec gaps to the reporter, move it to In Progress, and print the spec summary. Use before implementing any ticket, e.g. `/start-ticket ACC-1234` or a Jira browse URL.
---

# Start ticket

The ticket is the **spec**. Its description, comments, parent, and every Confluence page it links together define what to build. The branch name carries no intent.

This skill sets up the spec and the ticket state. It finishes when the spec summary is printed. Branching, code and MRs come afterwards and follow `.claude/conventions.md`.

The spec standard is section 6 of [Writing Specs for Agent-Implemented Tickets](https://genieitsoultions.atlassian.net/wiki/spaces/ACC/pages/3278372866/Writing+Specs+for+Agent-Implemented+Tickets).

## Input

A ticket key (`ACC-1234`) or a browse URL (`https://genieitsoultions.atlassian.net/browse/ACC-1234`). If you get a URL, extract the key from it. If no key is given, ask the user for one.

## Atlassian calls

- **Site:** pass `cloudId` `genieitsoultions.atlassian.net` on every call.
- **Primary tools** are called directly: `getJiraIssue`, `listJiraIssueComments`, `getConfluenceContent`, `atlassianUserInfo`.
- **Other operations** go through the execute-family tools:
  - `executeRead`: `listJiraIssueRemoteIssueLinks`, `listJiraIssueTransitions`.
  - `executeWrite`: `transitionJiraIssue`, `editJiraIssue`, `addOrEditJiraIssueComment`.
- **If a name is rejected,** run `discover` to find its current name.

## 1. Fetch the spec

- **The issue.** Call `getJiraIssue` with `view: "evidence"` and `responseContentFormat: "markdown"`. This returns status, type, assignee, reporter, parent, issue links and sub-tasks.
- **The comments.** Call `listJiraIssueComments` and page it until `isLast`. A later comment can narrow or override the description.
- **Linked pages.** Call `listJiraIssueRemoteIssueLinks` to find the linked Confluence pages and MRs.
- **Every Confluence page,** whether linked from the description or from the remote links. Read each with `getConfluenceContent` (`content_format: "markdown"`, `detail: "full"`). These pages are part of the spec.
- **The parent,** if the ticket has one. Read its summary and description, since sub-tasks inherit context from the parent.

**Done when:** every linked page has been read in full, along with all comments and the parent.

## 2. Check the spec for gaps

A **gap** is a required part of the spec that is missing or too vague to test.

**Every ticket needs:**
- **Goal**, or an opening statement of what the ticket achieves.
- **Scope**, with explicit In Scope and Out of Scope lists.
- **Acceptance Criteria**: numbered, each independently testable. A criterion like "works correctly" or "handled properly" counts as a gap.

**Tickets that involve branching logic, calculations, or money, accounting or state changes also need:**
- **Business Rules** with concrete values.
- **Worked Examples** with fully computed numbers.
- A **Scenario Matrix**, when there are several branching cases.

**Contradictions are gaps too:** between the description and the comments, between the description and a linked page, or between the ticket and its parent.

**Done when:** every item above is checked off as present or listed as a gap.

## 3. Raise the gaps with the reporter

Skip this step if step 2 found no gaps.

1. **Draft one comment** that @-mentions the reporter.
   - List each gap concretely.
   - Where it helps, propose wording they can accept or correct.
2. **Show the draft to the developer.**
3. **Post it only after they confirm.** Use `addOrEditJiraIssueComment`.

The description belongs to the reporter, so every gap is answered in the comment thread, never by editing the description. If the developer chooses to proceed before the reporter answers, record each choice as an **assumption** in the summary.

**Done when:** the developer has either confirmed the comment, which you then post, or declined it.

## 4. Move the ticket to In Progress

**Transition:**
- Transition only tickets whose status category is **To Do**. Leave any other status as it is.
- Call `listJiraIssueTransitions` and pick the transition whose target status is `In Porgress`. That spelling is the real ACC status name, id `10103`. The transition that leads there is named `In Development`.
- Match on the target status, not the transition name. Pending, QA Review, Test and Ready to Deploy also sit in the In Progress category, but they are the wrong target.
- Call `transitionJiraIssue` with that transition.

**Assign:**
- If the ticket is unassigned, assign it to the current user: get the accountId from `atlassianUserInfo`, then call `editJiraIssue` with `assignee: {"accountId": ...}`.
- If someone else is already assigned, leave the ticket as it is and name that person in the summary.

**Done when:** the ticket is `In Porgress` with an assignee, or the summary explains why it is not.

## 5. Print the spec summary

The summary is the checklist the implementation is verified against. Include:

- **Ticket:** key, summary, status (before → after), assignee, parent.
- **Goal**
- **In Scope / Out of Scope**, including cross-linked sibling tickets.
- **Acceptance Criteria**: numbered, verbatim, as a checklist.
- **Business Rules / Worked Examples**, if present. Worked examples are the ground truth to reproduce.
- **Linked pages:** titles and links.
- **Open gaps:** each gap, whether the comment was posted, and every assumption the developer chose.

The CLAUDE.md ticket rules then carry the rest of the work: comment on the ticket for each significant step, and re-fetch it whenever the description changes.
