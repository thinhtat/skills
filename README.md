# Accountia skills

Agent skills for the Accountia delivery pipeline: `/intent` → `/design-spec` → `/design-to-tickets` → `/build-plan` → `/build-execute`, plus `/review-code-review`, `/orchestration-workflow` and helpers. Each skill is a folder under [`skills/`](skills/) with a `SKILL.md`.

> Internal to Genie. Host this repo privately (company GitLab) and share it only inside Genie.

## Install

The skills install with the [`skills`](https://www.npmjs.com/package/skills) CLI (Node.js 22.20+), the same way as `mattpocock/skills`. Run one command in the repo or workspace where you work with Claude Code:

```bash
# All Accountia skills, for Claude Code, in this project
npx skills add <this repo's git URL> --skill '*' -a claude-code

# Or across all your projects
npx skills add <this repo's git URL> --skill '*' -a claude-code -g
```

The URL is the repo's SSH or HTTPS clone URL; the CLI uses your existing Git credentials, so a private repo works for anyone with access. Update later with `npx skills update`, remove with `npx skills remove <name>`.

### Dependencies install themselves

Some skills read other skills as sibling folders (`../<name>/SKILL.md`). The CLI has no dependency field, so each such skill carries a **Dependencies** section: on its first run it checks that every sibling is there and, after asking you, installs a missing one with `npx skills add <source> --skill <name> -a claude-code -y` in the same scope (project, or `-g`).

| Skill | Siblings it reads |
|---|---|
| `design-spec` | `to-spec` (mattpocock/skills), `review-loop` |
| `design-to-tickets` | `to-tickets` (mattpocock/skills), `jira-ticket`, `review-loop` |
| `review-code-review` | `code-review` (mattpocock/skills), `jira-ticket`, `accountia-conventions`, `review-loop` |
| `build-plan` | `jira-ticket`, `accountia-conventions`, `review-loop` |
| `build-execute` | `accountia-conventions` |
| `intent` | `review-loop` |
| `orchestration-workflow` | `to-tickets` (mattpocock/skills), `design-to-tickets`, `build-plan`, `jira-ticket`, `accountia-conventions`, `review-loop` |

To install everything up front instead, without waiting for a first run:

```bash
npx skills add mattpocock/skills --skill to-spec --skill to-tickets --skill code-review -a claude-code
```

Keep both in the same scope: a project-scoped skill cannot see a sibling installed with `-g`, and the reverse. The `/setup-matt-pocock-skills` step those three mention is not needed: the Accountia skills override their tracker setup.

## Requirements

These are tools, not skills, so the CLI cannot install them. Set them up once:

| Needed by | Requirement |
|---|---|
| `/build-execute`, `/orchestration-workflow` | Claude Code plugin **superpowers**: `/plugin install superpowers@claude-plugins-official` |
| every skill with a review step | **Plannotator** CLI, plus its `plannotator-annotate` skill in `~/.claude/skills/` |
| Jira and Confluence reads and writes | **Atlassian MCP** server (see `.mcp.json`) |
| `/build-execute`, `/review-code-review` | **glab**, logged in to gitlab.com |
| design and build skills | a `workspace/` directory: `workspace/<module>/main` worktrees and `workspace/docs/` |

## Skills

| Skill | Purpose |
|---|---|
| `intent` | Capture a feature intent. |
| `design-spec` | Turn an intent into a spec. |
| `design-to-tickets` | Break a Jira or local spec into reviewed tickets. |
| `build-plan` | Write implementation plans for a ticket. |
| `build-execute` | Execute the plans with superpowers in worktrees. |
| `review-code-review` | Review a branch or GitLab MR against Jira spec, conventions and QA scenarios. |
| `orchestration-workflow` | Run a ticket end to end with Orca workers: tickets, plans, implementation. |
| `posting-artifact` | Publish journal-entry scenario artifacts. |
| `accountia-conventions` | Shared: the team's development conventions. |
| `review-loop` | Shared: the Plannotator review loop. |
| `jira-ticket` | Shared: how to read a Jira ticket in full. |

## Developing the skills

Edit the source in `skills/<name>/`. To run your edits in Claude Code inside this repo, link them into `.claude/skills/` once:

```powershell
./scripts/link-local.ps1
```

The links are directory junctions (no admin rights needed) and are git-ignored. `CLAUDE.md` imports `skills/accountia-conventions/conventions.md`, so the conventions load in every session here.
