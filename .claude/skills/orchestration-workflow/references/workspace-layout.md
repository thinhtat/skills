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
        ├── refinement/<TICKET>/
        └── plans/<TICKET>/
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

## Refinement (phase 2)

```bash
cd <root>
/refinement ACC-1234 --repo workspace/accountia-backend/main,workspace/accountia-frontend/main
```

Refinement resolves a repo as `<root>/<repo>`, where root is the directory holding `.claude/skills/refinement/` or the cwd. Both of these miss:

- `--repo accountia-backend` — that path does not exist at the root; only `workspace/accountia-backend/main` does.
- `--repo D:\...\workspace\accountia-backend\main` — an absolute path bypasses the root-relative resolution refinement expects.

The relative path makes `$REPO/.ua` and `git -C $REPO rev-parse HEAD` both land on the main worktree, which is the graph phase 1 just verified.

### Where refinement actually writes

Refinement fixes its output at `<root>/docs/refinement/<ISSUE-KEY>/`, where root is the directory containing `.claude/skills/refinement/` — cwd does not change it. This workflow's docs root is `$WS/docs`, so after the worker reports its folder the coordinator moves it:

```bash
mkdir -p "$WS/docs/refinement"
mv "<root>/docs/refinement/ACC-1234" "$WS/docs/refinement/ACC-1234"
```

A timestamped folder (`<KEY>-<YYYYMMDD-HHMMSS>`, produced when the target already existed) moves the same way, keeping its name. Leave nothing behind at the root; never overwrite an existing folder in `$WS/docs`.

## Worktrees (phase 4)

```bash
git -C "$WS/accountia-backend/main" worktree add \
  "$WS/accountia-backend/ACC-1234-<slug>" \
  -b "feat/ACC-1234-<slug>"
```

Case type: Story → `feat`, Bug → `fix`, Task → `feat`. Slug: ticket title, per `.claude/conventions.md` (branch `<case-type>/<ticket-key>-<title-as-slug>`).

Verify it branches from main's HEAD and leaves main untouched:

```bash
git -C "$WS/accountia-backend/main" worktree list
git -C "$WS/accountia-backend/main" log --oneline -1
git -C "$WS/accountia-backend/main" status -sb
```

Removing one later is the developer's call — this workflow does not prune.
