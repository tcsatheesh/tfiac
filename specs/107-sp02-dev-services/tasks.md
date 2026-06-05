# Tasks — Feature 107 (sp02/dev services instance)

**Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md).
Engine [006-services](../006-services/spec.md) is UNCHANGED — these tasks add
one tfvars file + one CI `paths:` entry and validate locally.

## Phase 1 — Author the instance

- [ ] **T-107-1** Create `variables/sp02/dev/services.tfvars.json` mirroring
  the current `variables/sp01/dev/services.tfvars.json` with: `topology=spoke`,
  `tenant=sp02`, `environment=dev`, `region=swc`, `usecase=uc1`; the six
  selected services; an empty `overrides`; the toggles from the plan table;
  `vnet_state_backend.key=sp02/npd/vnet.tfstate`;
  `dns_state_backend.key=hub/prd/dns.tfstate`; runtime
  `subscription_id` placeholder. (FR-107-01/02/03, C-107-03/04)

- [ ] **T-107-2** Wire CI: add `variables/sp02/dev/services.tfvars.json` to
  BOTH the `pull_request.paths` and `push.paths` lists in
  `.github/workflows/services.yml`. (FR-107-05)

## Phase 2 — Validate (local, no live state)

- [ ] **T-107-3** `terraform fmt -recursive` clean across the repo.

- [ ] **T-107-4** Engine green: in `terraform/services` run `terraform init
  -backend=false` + `terraform validate` + `terraform test`. All must pass
  (engine untouched). (Acceptance 1)

- [ ] **T-107-5** Structural check on the new tfvars: valid JSON; confirm the
  six selected services and an empty `overrides`; confirm
  `vnet_state_backend.key=sp02/npd/vnet.tfstate`. (FR-107-03, Acceptance 2)

- [ ] **T-107-6** Confirm `services.yml` watches the new path (grep).
  (Acceptance 3)

## Phase 3 — Ship

- [ ] **T-107-7** Commit on `106-sp02-spoke-vnet-services` (same branch/PR as
  106), push, ensure CI green, squash-merge.

## Phase 4 — Rollout (operator-run, post-merge, via workflow ONLY)

- [ ] **T-107-8** AFTER the sp02 spoke vnet (106) is applied:
  `gh workflow run deploy.yaml --ref master -f service=services -f tenant=sp02
  -f environment=dev -f action=apply -f apply=true`; `gh run watch` to green.
  (FR-107-04, Acceptance 4)
