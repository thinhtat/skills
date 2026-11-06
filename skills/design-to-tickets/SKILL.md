---
name: design-to-tickets
description: Break a spec (a Jira issue, or a spec.md from workspace/docs/design/specs/) into reviewed tickets under workspace/docs/design/plans/, optionally created as Jira issues.
disable-model-invocation: true
---

# Design to tickets

Breaks one **spec** (a Jira issue, or a `spec.md` written by `/design-spec`) into **tickets**, using the process and templates of `/to-tickets` with the spec as the source. The tickets are written locally, reviewed, and then optionally created as Jira issues. It finishes when the tickets live locally or in the Jira backlog, or earlier when the user closes the review.

`$WS` is the `workspace` directory: the nearest ancestor of the current directory that contains `workspace/` (today `D:\projects\proj-accountia\workspace`).

## Dependencies

This skill reads sibling skills: `to-tickets` (mattpocock/skills), `jira-ticket` (Accountia), `review-loop` (Accountia). Before anything else, check that each has a `SKILL.md` in a folder beside this skill's own. For each missing one, ask the user, then install it with `npx skills add <source> --skill <name> -a claude-code -y`, adding `-g` when this skill sits under the home directory. The Accountia source is the `source` recorded for this skill in `skills-lock.json`; if none is recorded, ask for it.

## 1. Pick the spec

The spec comes from one of two **sources**:

- **Jira:** an issue (`ACC-8585`) whose content is the spec.
- **Local:** a `spec.md` under `$WS/docs/design/specs/`.

Choose the source from the argument:

- **Issue key or browse URL** → Jira. Extract the key from a URL.
- **Path to a `spec.md`** → Local.
- **No argument** → ask the user with AskUserQuestion: Jira or Local. For Jira, ask for the issue key. For Local, list every `$WS/docs/design/specs/*/spec.md`, mark the ones that already have tickets (a folder under `$WS/docs/design/plans/` ending in the same slug), and ask which one to break down.

Then read the spec:

- **Jira:** read it as [`../jira-ticket/SKILL.md`](../jira-ticket/SKILL.md) describes: the issue, all comments, the parent, and every linked Confluence page. Jira is read only here. The issue's existing sub-tasks lie outside the spec. Treat the issue as if it had none: skip their content, and derive the whole breakdown in step 2 from the spec alone.
- **Local:** read `spec.md`, and the intent its `Source intent:` line names.

The **spec slug** used in step 2 is:

- **Jira:** `<KEY>-<summary-slug>`, where the summary slug is the issue summary in lowercase, words joined by hyphens, cut short if long.
- **Local:** the spec folder's name without its date prefix.

The **spec reference** is `<KEY> (<browse URL>)` for Jira and the path to `spec.md` for Local.

Done when exactly one spec is chosen and every source listed for it has been read in full.

## 2. Break the spec into tickets

Read [`../to-tickets/SKILL.md`](../to-tickets/SKILL.md) and follow its process and templates, with these overrides:

- **Source.** The spec is the input.
- **Quiz.** The review of step 3 replaces its quiz step: present the breakdown there, not in chat.
- **Repo prefix.** Each ticket changes exactly one repo, and its title starts with that repo's prefix: `# <NN>: [BE] <title>`.

  | Prefix | Repo |
  |---|---|
  | `[BE]` | `accountia-backend` |
  | `[FE]` | `accountia-frontend` |
  | `[CI/CD]` | `cicd-template` |

  Find each slice's repos while exploring the codebase. A slice that crosses repos becomes one ticket per repo, each the narrowest complete path within its repo, and the consumer is blocked by the provider: an `[FE]` ticket by the `[BE]` ticket whose API it calls, a ticket that needs a new cicd-template release by its `[CI/CD]` ticket. For a slice in any other repo, ask the user which prefix to use.
- **Out of scope.** Each ticket ends with an `**Out of scope:**` list, after its acceptance criteria. It names what an implementer of this ticket might reasonably build but must leave alone, one line per item, each with its source:
  - every item the spec puts out of scope, as a non-goal, a later phase or a deferral, that touches this ticket's area, quoted or closely paraphrased from the spec (`spec: <section>`);
  - every part of the spec that a sibling ticket delivers instead, above all the other repo's side of a shared slice (`ticket <NN>`);
  - every open question in the spec that this ticket's area depends on, which this ticket builds around without answering (`open question: <the question>`).

  When none applies, write `None beyond the spec's stated scope.`
- **Publish.** Use the local-files form, writing one file per ticket to the **plan folder** `$WS/docs/design/plans/<DD-MM-YYYY>-<spec-slug>/<NN>-<slug>.md`. The date is today; the spec slug comes from step 1. Create `$WS/docs/design/plans/` if it does not exist. If the plan folder already exists, ask the user whether to update those tickets or pick a new slug. The first line under each title is `Source spec: <spec reference>`.

Done when every user story of the spec is delivered by at least one ticket, every ticket carries exactly one repo prefix, every ticket's blocking edges name existing tickets, every ticket has an Out of scope list, and every out-of-scope item the spec states appears in at least one ticket's list. For a Jira spec with no user stories, every acceptance criterion and functional requirement takes their place.

## 3. Review the tickets

Run the [review loop](../review-loop/SKILL.md) on the plan folder. Re-check the step-2 completion criterion after each round of edits.

## 4. Create Jira issues (optional)

Ask the user whether to create the tickets in the Jira backlog.

- **No:** stop; the local tickets are the result. Print the plan folder path.
- **Yes:**
  1. Check that the Atlassian MCP tools are available and that `getAccessibleAtlassianResources` returns a site. If either fails, tell the user, print the plan folder path, and stop.
  2. Pick where the issues go:
     - **Story spec** (a Jira spec whose issue type is Story): every ticket becomes a **sub-task** of that story, in the story's project, with the project's sub-task issue type (its exact name from the project's issue-type metadata). Ask nothing here. Before creating, list the story's existing sub-tasks; for each ticket whose repo prefix and title match an existing sub-task, ask the user whether to create it anyway or skip it and record the existing key instead.
     - **Any other spec** (Local, or a Jira issue of another type): ask for the project key, the issue type, and an optional parent issue. For a Jira spec, offer the spec's issue as the parent.

     The story or parent issue itself stays unchanged.
  3. Create one issue per ticket in dependency order (blockers first), using the issue template of `/to-tickets` with an `## Out of scope` section after `## Acceptance criteria` that carries the local ticket's list. The summary is the ticket title with its repo prefix (`[BE] <title>`). A sub-task follows its story's sprint; any other issue goes to the backlog (no sprint). Set each blocking edge as a native "blocks" issue link. Find the create and link operations with `discover`.
  4. Add a `**Jira:** <KEY>` line under each local ticket's title, and print every created key with its link.

Done when every local ticket carries the key of its Jira issue, every blocking edge exists as a link, and, for a story spec, every created issue is a sub-task whose parent is the story.
