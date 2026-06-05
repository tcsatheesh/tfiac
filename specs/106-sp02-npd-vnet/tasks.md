# Tasks — Feature 106 (sp02/npd vnet instance)

**Spec**: [spec.md](./spec.md) · **Plan**: [plan.md](./plan.md).
Engine [004-vnet](../004-vnet/spec.md) is UNCHANGED — these tasks add one
tfvars file + one CI `paths:` entry and validate locally.

## Phase 1 — Author the instance

- [ ] **T-106-1** Create `variables/sp02/npd/vnet.tfvars.json` mirroring
  `variables/sp01/npd/vnet.tfvars.json` with: `tenant=sp02`,
  `environment=npd`, `role=spoke`, `usecase=shd`, `region=swc`,
  `address_space=["10.240.6.0/23"]`, `enable_spoke_nat_gateway=true`, the
  eight subnet roles in the `10.240.6.0/23` block, `hub_state_backend.key=
  hub/npd/vnet.tfstate`, `dns_state_backend.key=hub/prd/dns.tfstate`, and the
  runtime `subscription_id` placeholder. (FR-106-01/02, C-106-02/03/04/05)

- [ ] **T-106-2** Wire CI: add `variables/sp02/npd/vnet.tfvars.json` to BOTH
  the `pull_request.paths` and `push.paths` lists in
  `.github/workflows/vnet.yml`. (FR-106-05)

## Phase 2 — Validate (local, no live state)

- [ ] **T-106-3** `terraform fmt -recursive` clean across the repo.

- [ ] **T-106-4** Engine green: in `terraform/vnet` and `modules/network`
  run `terraform init -backend=false` + `terraform validate` + `terraform
  test`. All must pass (engine untouched). (Acceptance 1)

- [ ] **T-106-5** Structural check on the new tfvars: valid JSON; confirm
  `address_space=["10.240.6.0/23"]` is disjoint from sp01 (`10.240.2.0/23`)
  and hub (`10.240.4.0/23`); confirm every subnet CIDR is inside
  `10.240.6.0/23`. (FR-106-03, Acceptance 2/3)

- [ ] **T-106-6** Confirm `vnet.yml` watches the new path (grep). (Acceptance 4)

## Phase 3 — Ship

- [ ] **T-106-7** Commit on `106-sp02-spoke-vnet-services`, push, open PR vs
  `master`, ensure CI green, squash-merge.

## Phase 4 — Rollout (operator-run, post-merge, via workflow ONLY)

- [ ] **T-106-8** `gh workflow run deploy.yaml --ref master -f service=vnet
  -f tenant=sp02 -f environment=npd -f action=apply -f apply=true` (hub vnet
  already exists); `gh run watch` to green. (FR-106-04, Acceptance 5/6)
