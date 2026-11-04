# Accountia — Development Conventions (synced from Confluence)

Source of truth: Confluence space `ACC` ("Accountia"), owned by Kovan Akrei (Chief Architect). This file is a working summary for Claude Code — for the authoritative text, follow the links.

- [Code Standards & Architectural guidelines](https://genieitsoultions.atlassian.net/wiki/spaces/ACC/pages/3175907329/Code+Standards+Architectural+guidelines) — umbrella doc, Active, v1.0
- [Git related naming conventions](https://genieitsoultions.atlassian.net/wiki/spaces/ACC/pages/3203563523/Git+related+naming+conventions) — repo, branch, commit, and PR naming, all consolidated onto this one page (no longer WIP; the old separate repo-naming page has been folded in and no longer exists on its own)
- [Tooling and CICD Standards](https://genieitsoultions.atlassian.net/wiki/spaces/ACC/pages/3176398850/Tooling+and+CICD+Standards)
- [Compliance and Enforcement](https://genieitsoultions.atlassian.net/wiki/spaces/ACC/pages/3176267785/Compliance+and+Enforcement)
- Per-stack (fetch when working in that repo): [Angular Standards](https://genieitsoultions.atlassian.net/wiki/spaces/ACC/pages/3176267777/Angular+Standards), [Java and Spring Boot Standards](https://genieitsoultions.atlassian.net/wiki/spaces/ACC/pages/3176169473/Java+and+Spring+Boot+Standards), [Database Standards](https://genieitsoultions.atlassian.net/wiki/spaces/ACC/pages/3175907336/Database+Standards), [API Design Standards](https://genieitsoultions.atlassian.net/wiki/spaces/ACC/pages/3176595457/API+Design+Stardards)
- [Writing Specs for Agent-Implemented Tickets](https://genieitsoultions.atlassian.net/wiki/spaces/ACC/pages/3278372866/Writing+Specs+for+Agent-Implemented+Tickets) — how ticket specs are structured (Scope, Business Rules, Scenario Matrix, Functional Requirements, Worked Examples, Acceptance Criteria; lighter Goal/Scope/AC variant for simple tickets) and how Claude Code fetches them before implementing (ACC-8546)
- [Test method name convention](https://genieitsoultions.atlassian.net/wiki/spaces/ACC/pages/2742812712/Test+method+name+convention) — unit/API/E2E test naming: `<method under test>_when_<scenario>_then_<expected outcome>`
- QA / accountia-e2e-test-robot (for ACC-8543): [Naming Conventions](https://genieitsoultions.atlassian.net/wiki/spaces/ACC/pages/3163947018/Naming+Conventions) (Robot Framework file/test naming), [Object Repository Guidelines](https://genieitsoultions.atlassian.net/wiki/spaces/ACC/pages/3132096513/Object+Repository+Guidelines), [Contribution Guide](https://genieitsoultions.atlassian.net/wiki/spaces/ACC/pages/3132030979/Contribution+Guide), [Test Design Guidelines](https://genieitsoultions.atlassian.net/wiki/spaces/ACC/pages/3131965441/Test+Design+Guidelines)

## Git: repos, branches, commits, PRs

- Repo name: `<solution>-<platform>-<target-area>`, e.g. `accountia-web-fe` (platform: `web` or `mob`; target area: `fe`, `be`, `test`, `app`, etc.).
- Branch name: `<case-type>/<ticket-key>-<ticket-title-as-slug>`, e.g. `feat/ACC-5010-set-up-a-new-user-role-for-invoicing`. Cut the title short if it's long.
- Commit message: `<case-type>: <ticket-key>-<Comment description>`, title case for the description, no trailing period, no URLs in the message, e.g. `feat: ACC-1991-Added user_id to USM-USR-3`.
- Case type (shared by branch names and commit messages — confirmed by Kovan Akrei on MR !5): one of `build`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `test` (drives semantic-release auto-versioning).
- PR name: `[ticket-key]-[ticket-title-as-slug]` — no case-type prefix, otherwise same pattern as branch name.
- All changes go through PRs — no direct pushes to trunk. At least one other engineer must review (AI review does not count as the required reviewer). Each PR must reference its Jira ticket. Squash-merge preferred for feature branches.

## Engineering principles (all languages)

- SOLID (Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion).
- Backend (Java and Python): strict 3-layer architecture — API layer (HTTP/validation/auth, no business logic, no direct data access) → Service layer (business logic, no HTTP/SQL) → Data layer (persistence, no business logic). Dependency direction is one-way; reverse dependencies forbidden.
- Write for the next developer. One thing per function (no "and"). No magic numbers/strings — named constants/enums. Document public APIs. Delete dead code, don't comment it out. Max 3 levels of nesting. Don't suppress lint/warnings without a written justification.

## Error handling

- Never swallow exceptions silently. Log with context (correlation ID, user/input state). Structured error payloads to API consumers. Custom exception types for domain errors. Distinguish recoverable (validation) vs system (DB unreachable) errors.

## Security baseline

- Never log secrets/PII. Validate/sanitize all input at the API layer. Parameterized queries only. Secrets never hardcoded or committed — env vars for config. Per Kovan (Jira ACC-8551/ACC-8583, 2026-09-09) and both the "Tooling and CICD Standards" and "Code Standards & Architectural guidelines" (Security Baseline) pages, now consistent as of 2026-09-10: **GitLab CI/CD variables for dev-environment secrets, Azure Vault for preprod/prod.** Confluence is explicitly not used for CI/CD secrets. Least-privilege service accounts and API keys. Dependencies kept current; vulnerabilities remediated within SLA.

## Testing

- All new code needs unit tests. Service-layer business logic: minimum 80% coverage. Integration tests required for external integrations (mock if no live test env). API Contract Tests required for all endpoints. Standalone-service E2E preferred (not solution-wide E2E). Tests must be deterministic — no real DB/network in unit tests. Test names follow `<method under test>_when_<scenario>_then_<expected outcome>` (e.g. `getUser_when_userNotFound_then_expect404`) — see [Test method name convention](https://genieitsoultions.atlassian.net/wiki/spaces/ACC/pages/2742812712/Test+method+name+convention).

## CI/CD (per repo)

Every repo's pipeline must run on every PR and every merge to trunk, and all stages must pass before merge: format check, lint (no errors), unit tests, coverage gate (80% target, being phased in), build artifact, security dependency scan.

## Compliance

PRs violating these standards must not be merged. Exceptions require Chief Architect approval, documented in the PR or an ADR. Standards doc is reviewed quarterly.

## Known discrepancies — do not silently resolve, flag instead

- **Repo naming mismatch**: the documented pattern is `<solution>-<platform>-<target-area>` (e.g. `accountia-web-fe`), but actual submodule names (`accountia-frontend`, `accountia-backend`, `location-service`, `ui-component-library`, ...) don't follow it. Likely applies to new repos going forward rather than a retroactive rename — confirm scope with Kovan.
- **Possibly stale page**: a 2022 "Development Rules" page also exists in the `ACC` space (Java Code Conventions, Checkstyle), predating the 2026 "Code Standards & Architectural guidelines" doc. Not linked above since it looks superseded — per reviewer feedback on this PR, its content is being merged into the current pages, so treat it as retired rather than a second, conflicting source.
- **Stale cross-references to a retired, pre-rebrand Confluence site (mostly resolved)**: "Angular Standards", "Java and Spring Boot Standards", and "Code Standards & Architectural guidelines" all used to link their test-naming (and, for the latter, Git branch naming) sections to a legacy Atlassian domain/space instead of the current `ACC` space pages — Kovan fixed all three on 2026-09-10 (see changelog below). Still open: "API Design Stardards" (version 1, unchanged since 2026-04-20) still opens by referring to the pre-rebrand company name ("Izy's backend services") instead of Accountia. Doesn't block using the page, but flag it to Kovan rather than resolving silently.
- **"Git related naming conventions" page self-contradicts on branch case-types**: its "Feature branch name" section's own prose example says case type is one of `feat`, `bugfix`, `hotfix`, but the same sentence links to the page's `#Type` anchor — which is the 8-entry table (`build`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `test`) written for commit messages, and doesn't include `bugfix`/`hotfix` at all. Kovan Akrei clarified on MR !5 that branch names and commit messages share the single 8-type list — treat the linked table as authoritative and the `feat`/`bugfix`/`hotfix` prose as stale, but the page itself hasn't been corrected yet.

Resolved since the initial draft of this file (kept here as a changelog, not a live concern):
- ~~"Java and Spring Boot Standards" and "Code Standards & Architectural guidelines" stale cross-references~~ — both pointed their test-naming section (and, for the latter, its Git branch naming link) at the legacy `izyas.atlassian.net` domain / a non-`ACC`-space page. Kovan fixed both on 2026-09-10: "Java and Spring Boot Standards" is now version 4 and links the current [Test method name convention](https://genieitsoultions.atlassian.net/wiki/spaces/ACC/pages/2742812712/Test+method+name+convention) page; "Code Standards & Architectural guidelines" is now version 9 and links the same page plus the consolidated [Git conventions](https://genieitsoultions.atlassian.net/wiki/spaces/ACC/pages/3203563523/Git+related+naming+conventions) page.
- ~~Secrets management conflict between "Tooling and CICD Standards" and "Code Standards & Architectural guidelines" (Security Baseline)~~ — the Security Baseline page said "Kubernetes secrets" while Tooling said Azure Vault; Kovan updated "Code Standards & Architectural guidelines" on 2026-09-10 (now version 6) to say "Use GitLab variables for DEV environment secrets and Azure Vault for PREPROD and PROD" — the two pages now agree.
- ~~Confluence listed as a secrets store~~ — Kovan updated "Tooling and CICD Standards" on 2026-09-09 to drop the Confluence-for-secrets line; confirmed on Jira ACC-8551/ACC-8583 that Confluence is never used for CI/CD secrets.
- ~~Source control tool mismatch (GitHub vs GitLab)~~ — "Tooling and CICD Standards" now correctly lists GitLab as the standard.
- ~~Git conventions page marked WIP~~ — the "Git related naming conventions" page is final and now also covers repo naming.
- ~~Unit-test naming convention missing~~ — see [Test method name convention](https://genieitsoultions.atlassian.net/wiki/spaces/ACC/pages/2742812712/Test+method+name+convention) above.
