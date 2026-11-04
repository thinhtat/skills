---
name: posting-artifact
description: Create or update a scenario-card artifact that documents and verifies Accountia journal-entry postings for one flow. `/posting-artifact <flow name | artifact URL> [new|update]`
disable-model-invocation: true
---

# Posting artifact

Build a Claude artifact, written in English, that documents and verifies the journal-entry postings for one Accountia **flow**: sales credit note, invoice refund, invoice payment, and so on. The source of truth is the backend at the latest `main` commit. Every number in the artifact must come from that code.

## Input

```
/posting-artifact <flow name | artifact URL> [new|update]
```

- **Flow name**: look it up in [`artifacts.md`](artifacts.md) by name or alias. Matching is case-insensitive.
- **Artifact URL**: a `claude.ai/artifact/…` or `claude.ai/code/artifact/…` link. This always means **update** that artifact.
- **Mode**:
  - If omitted, the mode is `update` when the flow has a row in the registry, and `new` otherwise.
  - `new` always publishes a fresh artifact, even when a row already exists. The new URL then replaces the old one in that row.
  - `update` on a flow with no row is a **miss**: stop and ask the user to rerun with the exact claude.ai URL of the artifact. Do not guess a URL from `Artifact` `list`.
- **Rule set**: Iraq (`rules/iq/…`, sessions `*-ks-iq`) unless the user names another. Describe only that rule set.

## Steps

### 1. Sync source

- Work in `D:/projects/proj-accountia/workspace/accountia-backend/main`.
- Run `git status`.
  - If the branch is not `main`, or the worktree has uncommitted changes, stop and report.
  - Do not stash, reset or switch branches.
- Run `git fetch origin`, then `git pull --ff-only origin main`. If the pull is not a fast-forward, stop and report.
- Record `git rev-parse --short HEAD` and the commit date.
- Run `git diff --name-only ORIG_HEAD HEAD`. The CodeGraph index may lag behind for the files it lists, so read those files from disk.

**Done when:** the worktree sits at the fetched `origin/main` and you have the hash.

### 2. Load the baseline

- **new**: read the template `https://claude.ai/code/artifact/9f3fe508-7caf-4833-aa1e-695cbfea675d` with `Artifact` `read`. Reuse its exact layout, CSS tokens and JS data model.
- **update**: read the target artifact with `Artifact` `read`, and edit the saved file that the read returns. Treat every existing scenario, number and finding as a claim to re-verify, not as fact. Note the commit hash in the old footer, then run `git diff --stat <old>..HEAD` on the rule and transaction paths to see what moved.

### 3. Research

- **CodeGraph first.** Run `codegraph_explore` with projectPath `D:/projects/proj-accountia/workspace/accountia-backend/main`.
- **Drools files.** `.drl` files under `api/src/main/resources/rules` are not indexed, so read them directly.
- **Trace the whole chain:**
  1. command handler
  2. validator
  3. posting-account resolution
  4. TransactionCreator: the `*Transaction` class, the session name, and any Java journal builder outside Drools
  5. every rule in the `.drl`
  6. the domain methods that compute the context amounts
  7. the `AccountType` codes
- **Where code and the CodeGraph index disagree, trust the file on disk.**

**Done when:** every reason, type and path branch reachable from the entry points has a rule or Java path mapped to it, or is marked as a gap.

### 4. Build the artifact

Sections, in this order:

1. **"Where <flow> comes from".** Entry-point cards, each giving the handler or class name and a one-line behaviour. Include rule-session selection and the transaction type.
2. **Matrix table.** One dimension is reason/type/path, the other is product/source/account; each cell gives the debited and credited account. Mark gaps with red "no rule" or "rejected" chips.
3. **Legend.** Cover:
   - the amounts every scenario always posts
   - the key formulas (liability, settlement, FX)
   - the booking date
   - currency conversion
4. **Filter bar.** All / Balanced / Flagged only, with a count.
5. **Scenario cards (15–25).** Each card has:
   - a title and a condition sentence
   - an "Input" key-value box
   - a "<SharedContext or settlement class>" key-value box with the values the code computes
   - a Dr/Cr table: account name, `AccountType · code`, and the rule or method name
   - a totals row
   - a balance chip: "Balanced: X", "Off by X", or "Rejected: no posting"
   - a posting-path chip, when more than one path exists
   - an optional Note
   - a red "Check." note giving the expected behaviour for any gap
6. **"Compare with posted entries".** Every card that has entries gets this `<details>` box:
   - The user pastes lines of the form `account, Dr|Cr, amount`.
   - Sub-ledger and payout codes match by prefix.
   - Each line shows as match, missing, differs or unexpected.
7. **"What to check".** The findings section.
8. **Footer.** List:
   - the commit hash and date
   - the source files read
   - what was not verified

**Scenarios must cover:**
- every reason/type/path branch, including non-Drools Java posting paths
- discounts, fees and foreign currency
- cash rounding
- the paid, partly paid, overpaid and refunded states
- validator rejections
- cancel and regret paths
- every path that produces unbalanced entries

**Numbers:**
- Use simple example numbers, and post exactly what the code posts.
- Keep real imbalances. Never invent behaviour.
- When a value depends on stored data or a system property, state the assumption in the card.

**On update:** the guarantees are the same as for new.
- Fix every claim that the current code contradicts.
- Add scenarios for new branches, and remove scenarios whose paths no longer exist.
- Mark the cards whose numbers changed with a "Changed since <old hash>" chip.

### 5. Publish and record

- Publish as a private artifact:
  - **new**: publish without a `url`.
  - **update**: publish with the target `url`.
- Do not ask the user any further questions.
- Update [`artifacts.md`](artifacts.md):
  - Write the flow, aliases, rule set, URL and short hash.
  - Add a row when the flow is new or arrived by URL.
  - Otherwise edit the existing row.
- Reply in Vietnamese with:
  - the link
  - the commit hash, plus the old hash on update
  - 3–5 bullets on the flagged findings; on update, what changed
  - what was not verified
