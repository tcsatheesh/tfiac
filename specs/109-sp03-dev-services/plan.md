# Plan — Feature 109 (sp03/dev services instance)

**Engine**: [006-services](../006-services/spec.md) (incl. FR-052). This
instance adds **no** engine code; it selects + parameterizes the engine.

## Technical context

- Stack: `terraform/services/` (unchanged).
- Inputs: `variables/sp03/dev/services.tfvars.json` + backend key
  `sp03/dev/services.tfstate`.
- Cross-stack reads: `sp03/npd/vnet.tfstate` (PE subnet, role `development`) and
  `hub/prd/dns.tfstate` (blob/vault/sql/datafactory/adf zone ids).

## Constitution check

- **Engine untouched** — PASS. No files under `terraform/services/` or
  `modules/*` change. Only the tfvars + a CI paths line + specs.
- **Single source of truth** — PASS. Only selects catalogued types; no new
  types/naming rows (those are 001 + 006/FR-052).
- **Private-by-default** — PASS. Every selected service is private: storage/KV
  PEs on; SQL + ADF are private-only; ADF public access off.
- **Runtime-configurable** — PASS. Subscription id injected at runtime.

## Approach

1. Author `variables/sp03/dev/services.tfvars.json` (4 services + PE toggles +
   subnet role + vnet/dns backends).
2. Register the tfvars path in `.github/workflows/services.yml`.
3. Roll out via `deploy` (services/sp03/dev) AFTER: F1–F3 merged, hub `dns`
   applied (new zones), and 108 sp03 vnet applied.
4. Provision `go-sqlcmd` on the deploy runner for the SQL grant.

## Risks

- SQL grant needs runner tooling + network path → provisioned/validated at
  rollout; `sql_grant_enabled` can be flipped off to grant manually.
- Policy-vs-TF `to-hub-la` diag race on new services → known remediation
  (delete orphan diag, re-dispatch) per repo ops notes.
