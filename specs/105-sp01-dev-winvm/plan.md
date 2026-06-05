# Plan — 105 sp01/dev Windows jump-box VM (instance)

## Approach

Pure instance feature over the shipped `008-winvm` engine. The only new file is
`variables/sp01/dev/winvm.tfvars.json`; the engine's `winvm` workflow already
lists that path in its `paths:` triggers, so no workflow edit is required (we
verify it). Rollout is via the generic `deploy` workflow with `service=winvm`.

## Constitution check

- **II (intent-only inputs):** tfvars sets high-level intent (tenant, env,
  region, usecase, RG name, KV id, subnet role, state backends). PASS.
- **VI (no provider blocks in wrappers):** N/A — instance adds tfvars only.
  PASS.
- **VII (backend key scheme `<tenant>/<env>/<stack>.tfstate`):** state key
  `sp01/dev/winvm.tfstate`. PASS.
- **IX (Azure platform resources via AVM):** inherited from the engine. PASS.
- **`10n` MUST NOT touch `00n`:** no edits to `specs/008-winvm/`,
  `modules/winvm/`, `terraform/winvm/`. PASS.
- **Private-by-default:** engine forces no public IP; VM reachable only via
  Bastion; KV is private. PASS.

## Inputs pinned (variables/sp01/dev/winvm.tfvars.json)

| Key | Value |
|---|---|
| `subscription_id` | `883c9081-23ed-4674-95c5-45c74834e093` |
| `tenant` | `sp01` |
| `environment` | `dev` |
| `region` | `swc` |
| `usecase` | `uc1` |
| `stack_purpose` | `svc` (so RG lookup = `rg-svc-uc1-sp01-dev-swc-001`) |
| `repo` | `tcsatheesh/tfiac` |
| `resource_group_name` | `rg-svc-uc1-sp01-dev-swc-001` (existing) |
| `subnet_role` | `development` |
| `key_vault_id` | full id of `kvfdyuc1sp01devswc001` |
| `vnet_state_backend.key` | `sp01/npd/vnet.tfstate` |
| `log_state_backend.key` | `hub/npd/log.tfstate` |

State SA for both remote states + backend: `sttfsshdhubnpdswc001` /
`rg-tfs-shd-hub-npd-swc-001`, container `tfstate`, subscription
`883c9081-23ed-4674-95c5-45c74834e093`.

## Validation

- Local: `terraform fmt -check` on the tfvars (JSON), and a
  `terraform init -backend=false && terraform validate` of `terraform/winvm`
  with `-var-file` is NOT meaningful without remote state; rely on the engine
  tests (already green) + the CI `winvm` job + the `deploy` plan job.
- CI: `winvm` workflow runs on the PR because the tfvars path is in `paths:`.

## Rollout

```bash
gh workflow run deploy.yaml --ref master \
  -f service=winvm -f tenant=sp01 -f environment=dev \
  -f action=apply -f apply=true
```
Watch with `gh run watch`; confirm the gated apply succeeded.

## Verification (read-only)

- VM `vm-jmp-uc1-sp01-dev-swc-001` exists in `rg-svc-uc1-sp01-dev-swc-001`,
  no public IP, private IP in the `development` subnet.
- KV secret `vm-jmp-uc1-sp01-dev-swc-001-admin-password` present in
  `kvfdyuc1sp01devswc001`.
