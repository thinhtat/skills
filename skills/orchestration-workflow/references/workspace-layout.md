# Workspace layout and command recipes

`$WS` is the `workspace` directory; `<root>` is its parent (`D:\projects\proj-accountia` today).

```
<root>/
├── accountia-all/          superrepo checkout — out of bounds
│   ├── .git/modules/       git's own bookkeeping for submodule worktrees
│   └── accountia-backend/  detached HEAD, no graphs — never a repo path
└── workspace/              $WS — the whole managed area
    ├── accountia-backend/
    │   └── main/           main worktree; .ua graph lives here
    ├── accountia-frontend/
    │   └── main/
    └── docs/
        ├── design/plans/<DD-MM-YYYY>-<TICKET>-<slug>/   ticket folder (phase 2)
        └── build/plans/<TICKET>/                       design.md + plans (phase 3)
```

A worktree created in phase 4 is a sibling of `main`, never inside it:

```
workspace/accountia-backend/main            <- branch main
workspace/accountia-backend/ACC-1234-...    <- branch feat/ACC-1234-...
```

## Why `accountia-all/` is not a working location

- Its submodules sit at a **detached HEAD** (`git submodule` checkouts, not a branch). Work committed there is unreachable from the default branch.
- They carry **no `.ua/` graphs**, so no phase can be grounded in them.
- The superrepo's own HEAD points at specific submodule commits; touching those checkouts silently changes what the superrepo records.

The worktrees under `workspace/` are the managed copies: on a branch, with graphs, branched from each other.

## Graph freshness (G3)

```bash
# graph hash
node -p "require('<abs path>/.ua/meta.json').gitCommitHash"
# repo HEAD
git -C <abs path> rev-parse HEAD
```

Equal → current. Unequal → stale. Missing `.ua/meta.json` → no graph; refresh full.

Refresh:

```bash
# POSIX
UNDERSTAND_NO_WORKTREE_REDIRECT=1 /understand "<abs path to $WS/<repo>/main>"
```

```powershell
# PowerShell
$env:UNDERSTAND_NO_WORKTREE_REDIRECT = '1'
/understand "<abs path to $WS/<repo>/main>"
```

`--full` only when there is no graph. An existing graph takes the incremental path.

### The redirect trap

`/understand` compares `git rev-parse --git-common-dir` against `--git-dir`. In a normal checkout or submodule they match; in a worktree the common dir is `accountia-all/.git/modules/<repo>` and the parent of that is the superrepo root — so the skill redirects, treating the worktree as ephemeral. Here that would write the graph into the superrepo's git directory and leave `workspace/<repo>/main/.ua` unchanged, so every later gate would keep failing.

`UNDERSTAND_NO_WORKTREE_REDIRECT=1` disables the redirect and keeps the graph where the worktree can use it.

A `.ua/` directly under `$WS/<repo>/` (beside `main`) belongs to no checkout in use. Ignore it: do not read it, do not move it into `main`, do not delete it.

## Tickets and plans (phases 2–3)

`/design-to-tickets` and `/build-plan` both resolve `$WS` as the nearest ancestor of their cwd that contains `workspace/`, so their output lands in `$WS/docs` wherever the worker starts under the root. Nothing needs relocating.

- `/design-to-tickets <TICKET>` writes the ticket folder `$WS/docs/design/plans/<DD-MM-YYYY>-<TICKET>-<slug>/`. If that folder already exists, the skill asks whether to update it or pick a new slug; the worker raises that as a question to the coordinator.
- `/build-plan <TICKET>` writes `$WS/docs/build/plans/<TICKET>/` and overwrites an existing plan folder.

## Worktrees (phase 4)

```bash
git -C "$WS/accountia-backend/main" worktree add \
  "$WS/accountia-backend/ACC-1234-<slug>" \
  -b "feat/ACC-1234-<slug>"
```

Case type: Story → `feat`, Bug → `fix`, Task → `feat`. Slug: ticket title, per the [development conventions](../../accountia-conventions/conventions.md) (branch `<case-type>/<ticket-key>-<title-as-slug>`).

Verify it branches from main's HEAD and leaves main untouched:

```bash
git -C "$WS/accountia-backend/main" worktree list
git -C "$WS/accountia-backend/main" log --oneline -1
git -C "$WS/accountia-backend/main" status -sb
```

Removing one later is the developer's call — this workflow does not prune.
