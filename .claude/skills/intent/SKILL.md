---
name: intent
description: Grill a rough idea into an intent.md under workspace/docs/intent/.
disable-model-invocation: true
---

# Intent

An **intent** is a one-page record of what should change and why, written before any design or code. This skill grills the user until the intent is sharp, then writes it to `$WS/docs/intent/<DD-MM-YYYY>-<slug>/intent.md`. It finishes when the user has approved or closed the review of that file. Design, tasks and code come afterwards.

## 1. Grill

Interview the user relentlessly about the idea, walking each branch of the decision tree and resolving decisions that depend on one another in order.

- Ask one question at a time, and give your recommended answer with it.
- Every answer comes from the user. When a question needs a fact (which systems are touched, how authentication works today), ask the user for it; the interview is the only source.
- Push every vague answer to a concrete one: which users, how many, which system, what evidence.
- Ask who the author is: name and role.

Done when each of the five sections below has a concrete answer the user has confirmed, and anything still unresolved is listed as an open question.

## 2. Write

**Path.** `$WS/docs/intent/<DD-MM-YYYY>-<slug>/intent.md`, where `$WS` is the `workspace` directory: the nearest ancestor of the current directory that contains `workspace/` (today `D:\projects\proj-accountia\workspace`). Never write it inside the skills repository or a code repository. Create `$WS/docs/intent/` if it does not exist. The date is today. The slug is a short lowercase kebab-case phrase naming the outcome, e.g. `customers-see-claim-status`. If the folder already exists, ask the user whether to update that intent or pick a new slug.

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

## 3. Review

Run the [review loop](../../shared/review-loop.md) on `intent.md`.
