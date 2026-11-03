---
name: design-to-tickets
description: Break a spec (a Jira issue, or a spec.md from workspace/docs/design/specs/) into reviewed tickets under workspace/docs/design/plans/, optionally created as Jira issues.
disable-model-invocation: true
---

# Design to tickets

Breaks one **spec** (a Jira issue, or a `spec.md` written by `/design-spec`) into **tickets**, using the process and templates of `/to-tickets` with the spec as the source. The tickets are written locally, reviewed, and then optionally created as Jira issues. It finishes when the tickets live locally or in the Jira backlog, or earlier when the user closes the review.

`$WS` is the `workspace` directory: the nearest ancestor of the current directory that contains `workspace/` (today `D:\projects\proj-accountia\workspace`).

## 1. Pick the spec

The spec comes from one of two **sources**:

- **Jira:** an issue (`ACC-8585`) whose content is the spec.
- **Local:** a `spec.md` under `$WS/docs/design/specs/`.

Choose the source from the argument:

- **Issue key or browse URL** → Jira. Extract the key from a URL.
- **Path to a `spec.md`** → Local.
- **No argument** → ask the user with AskUserQuestion: Jira or Local. For Jira, ask for the issue key. For Local, list every `$WS/docs/design/specs/*/spec.md`, mark the ones that already have tickets (a folder under `$WS/docs/design/plans/` ending in the same slug), and ask which one to break down.

Then read the spec:

- **Jira:** fetch it as step 1 of [`../start-ticket/SKILL.md`](../start-ticket/SKILL.md) describes, using its Atlassian calls section: the issue, all comments, the parent, and every linked Confluence page. Jira is read only here. The issue's existing sub-tasks lie outside the spec. Treat the issue as if it had none: skip their content, and derive the whole breakdown in step 2 from the spec alone.
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
- **Publish.** Use the local-files form, writing one file per ticket to the **plan folder** `$WS/docs/design/plans/<DD-MM-YYYY>-<spec-slug>/<NN>-<slug>.md`. The date is today; the spec slug comes from step 1. Create `$WS/docs/design/plans/` if it does not exist. If the plan folder already exists, ask the user whether to update those tickets or pick a new slug. The first line under each title is `Source spec: <spec reference>`.

Done when every user story of the spec is delivered by at least one ticket, and every ticket's blocking edges name existing tickets. For a Jira spec with no user stories, every acceptance criterion and functional requirement takes their place.

## 3. Review the tickets

Run the [review loop](../../shared/review-loop.md) on the plan folder. Re-check the step-2 completion criterion after each round of edits.

## 4. Create Jira issues (optional)

Ask the user whether to create the tickets in the Jira backlog.

- **No:** stop; the local tickets are the result. Print the plan folder path.
- **Yes:**
  1. Check that the Atlassian MCP tools are available and that `getAccessibleAtlassianResources` returns a site. If either fails, tell the user, print the plan folder path, and stop.
  2. Ask for the project key, the issue type, and an optional parent issue. For a Jira spec, offer the spec's issue as the parent. The parent issue itself stays unchanged.
  3. Create one issue per ticket in dependency order (blockers first), using the issue template of `/to-tickets`, in the backlog (no sprint). Set each blocking edge as a native "blocks" issue link. Find the create and link operations with `discover`.
  4. Add a `**Jira:** <KEY>` line under each local ticket's title, and print every created key with its link.

Done when every local ticket carries the key of its Jira issue and every blocking edge exists as a link.
