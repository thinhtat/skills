---
name: intent
description: Grill a rough idea into an intent.md under workspace/docs/intent/.
disable-model-invocation: true
---

# Intent

An **intent** is a one-page record of what should change and why, written before any design or code. This skill grills the user until the intent is sharp, then writes it to `intent.md` in its intent folder. It finishes when the user has approved or closed the review of that file. Design, tasks and code come afterwards.

`$WS` is the `workspace` directory: the nearest ancestor of the current directory that contains `workspace/` (today `D:\projects\proj-accountia\workspace`).

## Dependencies

This skill reads sibling skills: `grill-with-docs`, `grilling`, `domain-modeling` (mattpocock/skills), `review-loop` (Accountia). Before anything else, check that each has a `SKILL.md` in a folder beside this skill's own. For each missing one, ask the user, then install it with `npx skills add <source> --skill <name> -a claude-code -y`, adding `-g` when this skill sits under the home directory. The Accountia source is the `source` recorded for this skill in `skills-lock.json`; if none is recorded, ask for it.

## 1. Pick the intent folder

The **intent folder** is `$WS/docs/intent/<DD-MM-YYYY>-<slug>/`. It holds `intent.md` and the grill rounds, and lives only under `$WS/docs/intent/`, never inside the skills repository or a code repository. Create `$WS/docs/intent/` if it does not exist. The date is today. The slug is a short lowercase kebab-case phrase naming the outcome, e.g. `customers-see-claim-status`. If the folder already exists, ask the user whether to update that intent or pick a new slug.

Done when the intent folder exists.

## 2. Grill

Read [`../grill-with-docs/SKILL.md`](../grill-with-docs/SKILL.md) and follow it, with the idea as the subject and these overrides:

- **Rounds in Plannotator.** Each round is a file, `<intent folder>/rounds/round-<NN>.md`, numbered from `01`. It opens with the facts your sub-agents found that bear on the round (short bullets with file references), then one `:::question` block per frontier question, carrying your recommendation as `Recommended:`. The block syntax and answer format are in the "Asking the reviewer questions" section of `~/.claude/skills/plannotator/SKILL.md`. Open the round with the `plannotator` tool when you have one, else run `plannotator annotate <round file>` with the Bash tool in the background; the answers arrive in its output. Record them as `- [x]` in the round file, then write the next round. A session that closes with no answers: ask the user in chat whether to reopen it or stop.
- **Docs location.** Treat `$WS/docs/` as the root for `domain-modeling`: the glossary is `$WS/docs/GLOSSARY.md`, ADRs go under `$WS/docs/adr/`.
- **Concrete answers.** Push every vague answer to a concrete one: which users, how many, which system, what evidence.
- **Author.** Ask who the author is: name and role.

Done when each of the five sections below has a concrete answer the user has confirmed, anything still unresolved is listed as an open question, and every term resolved along the way is in the glossary.

## 3. Write

Write `<intent folder>/intent.md`.

**Content.** Exactly these five sections, in this order, and nothing more. Status is always `draft`.

- **Problem**: what hurts today and for whom, with the evidence.
- **Proposed outcome**: the observable result for users, stated as an outcome rather than a design.
- **Affected users and systems**: every role, team and system the change touches.
- **Constraints**: the limits the solution must respect.
- **Open questions**: what is still unresolved.

Example:

```markdown
# Intent: claims status self-service
Author: J. Ortiz (claims operations). Status: draft.

## Problem
Customers phone the contact center to ask where their claim is.
Handlers spend roughly a third of call time on status-only queries.

## Proposed outcome
Customers see claim status, next step and expected date in the portal.

## Affected users and systems
Claims handlers, portal team, claims-core API.

## Constraints
No new PII in the portal session. Existing authentication only.

## Open questions
Do third-party loss adjusters need access too?
```

Print the path of the written file.

## 4. Review

Run the [review loop](../review-loop/SKILL.md) on `intent.md`.
