# Tasks — 105 sp01/dev Windows jump-box VM (instance)

## Phase 1 — Author the instance

- **T-105-1** — Create `variables/sp01/dev/winvm.tfvars.json` with the inputs
  pinned in `plan.md` (FR-105-1, FR-105-2). No secret material (FR-105-3).
- **T-105-2** — Confirm the `winvm` workflow `paths:` already includes
  `variables/sp01/dev/winvm.tfvars.json` (added with the engine). If missing,
  it is an ENGINE change — out of scope here; STOP and amend `008` separately.
  (FR-105-4.)

## Phase 2 — Guardrails

- **T-105-3** — Verify no `008-winvm` engine artifact is modified by this branch
  (`git diff --name-only master` touches only `specs/105-*` + the tfvars).
  (FR-105-5, INS-105-4.)
- **T-105-4** — Sanity-check the JSON is well-formed and the KV id /
  RG name / state keys match live resources.

## Phase 3 — CI + merge

- **T-105-5** — Commit, push, open PR against master. The `winvm` CI job must be
  green (it runs because the tfvars path changed).
- **T-105-6** — Squash-merge; delete branch.

## Phase 4 — Rollout + verify

- **T-105-7** — Dispatch `deploy.yaml` `service=winvm tenant=sp01
  environment=dev action=apply apply=true`; watch to completion (FR-105-6).
- **T-105-8** — Read-only verify: VM present (no public IP) + KV secret
  `vm-jmp-uc1-sp01-dev-swc-001-admin-password` present (FR-105-6, INS-105-2/3).
