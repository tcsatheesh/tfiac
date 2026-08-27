# Plan — Feature 108 (sp03/npd vnet instance)

**Engine**: [004-vnet](../004-vnet/spec.md). This instance adds **no** engine
code; it is a pure parameterization.

## Technical context

- Stack: `terraform/vnet/` (unchanged), module `modules/network/` (unchanged).
- Inputs: `variables/sp03/npd/vnet.tfvars.json` (this feature's only real
  artifact) + backend state key `sp03/npd/vnet.tfstate`.
- Providers/backend: identical to sp01/sp02 (azurerm, OIDC, hub-internal state
  SA via the in-VNet runner).

## Constitution check

- **Engine untouched** — PASS. No files under `modules/network/` or
  `terraform/vnet/` change. `10n` instance features MUST NOT alter `00n`
  engines (CLAUDE.md).
- **Single source of truth** — PASS. No new resource types or naming rows
  (those are engine + 001). This instance only selects the existing spoke role.
- **Private-by-default** — PASS. Spoke has no public ingress; egress via spoke
  NAT gateway; workload private endpoints land in the `development` subnet.
- **Runtime-configurable** — PASS. Everything pinned in tfvars; subscription id
  injected at runtime.

## Approach

1. Author `variables/sp03/npd/vnet.tfvars.json` (CIDR `10.240.8.0/23`, 8
   subnets, spoke NAT gateway on, hub + dns state backends).
2. Register the tfvars path in `.github/workflows/vnet.yml` (both triggers).
3. Roll out via `deploy` (vnet/sp03/npd) after F1–F3 + this merge.

## Risks

- CIDR overlap → mitigated by the estate-wide allocation table (disjoint).
- Rollout requires the in-VNet runner online (see repo ops notes).
