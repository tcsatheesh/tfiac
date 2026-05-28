# Delivery Summary — Features 002, 003, 004

**Branch**: `master` (5 commits ahead of `origin/master`)

All work is on master, ready for `terraform plan` / `apply`. No terraform
runs have been performed against Azure — as instructed.

## Test inventory (all green)

| Stack | Pass | Fail |
|---|---|---|
| `modules/naming` | 41 | 0 |
| `terraform/dns` | 13 | 0 |
| `terraform/log-npd` | 3 | 0 |
| `terraform/log-prd` | 3 | 0 |
| `terraform/vnet-hub-npd` | 3 | 0 |
| `terraform/vnet-sp01-npd` | 3 | 0 |
| **Total** | **66** | **0** |

Re-run anywhere with:
```sh
for d in modules/naming terraform/dns terraform/log-npd terraform/log-prd terraform/vnet-hub-npd terraform/vnet-sp01-npd; do
  echo "### $d"; (cd "$d" && terraform test)
done
```

## Commit log (this session)

| Hash | Title |
|---|---|
| `cedd020` | naming(engine): add pdnsz catalogue entry + swedencentral region code |
| `e018814` | dns(feature 002): private DNS zones engine-driven stack (Phases 1-3) |
| `32b297c` | dns(feature 002): Phases 4-7 — custom zones, disable, US4 tests, polish |
| `a6a8fae` | feat(003): centralized Log Analytics workspaces for npd + prd hubs |
| `ca232f4` | feat(004): hub-and-spoke network foundation (vnet + NSGs + bastion + firewall + peering) |

## Feature 002 — Private DNS

- **Module**: `modules/dnszones/`
- **Stack**: `terraform/dns/` (prd-hub-only)
- **What you can plan**: 50+ Azure Private DNS zones (engine catalogue
  defined under `modules/dnszones/locals.tf`), all named via the naming
  engine (`pdnsz-…`) and tagged with the 6-key baseline.
- **Subscription pin** + **region allowlist** in
  [terraform/dns/validate.tf](terraform/dns/validate.tf).
- **Run**:
  ```sh
  cd terraform/dns
  cp ../../variables/hub/prd/dns.tfvars.example terraform.tfvars
  # edit subscription_id to your prd-hub sub
  terraform init && terraform plan
  ```

## Feature 003 — Centralized Log Analytics

- **Module**: `modules/loganalytics/`
- **Stacks**: `terraform/log-npd/`, `terraform/log-prd/`
- **What you can plan**: two workspaces (`log-hub-npd-sdc-001`,
  `log-hub-prd-sdc-001`) at 30-day retention, SKU `PerGB2018`, each in
  its own RG.
- **Consumer pattern** documented in each stack README — producer
  stacks pull `workspace_id` via `terraform_remote_state`.
- **Run**:
  ```sh
  cd terraform/log-npd
  cp ../../variables/hub/npd/log.tfvars.example terraform.tfvars
  terraform init && terraform plan

  cd ../log-prd
  cp ../../variables/hub/prd/log.tfvars.example terraform.tfvars
  terraform init && terraform plan
  ```

## Feature 004 — Hub & Spoke Network

- **Module**: `modules/network/` + sub-modules `modules/network/bastion/`
  and `modules/network/firewall/`
- **Stacks**: `terraform/vnet-hub-npd/`, `terraform/vnet-sp01-npd/`
- **Subnet role catalogue** (intent-driven, lives inside the module):
  `development`, `pre-production`, `api-management`, `buildsvr`,
  `bastion`, `firewall`, `firewall-mgmt`, `function-app`, `logic-app`,
  `preprod-func`, `preprod-logic`.
- **Hub stack**: vnet `10.240.4.0/23` + 7 subnets + per-subnet NSGs
  (with mandatory Bastion rule set) + Azure Bastion + Azure Firewall
  (Standard) + route table forwarding `0.0.0.0/0` to firewall private IP.
- **Spoke stack**: vnet `10.240.2.0/24` + 6 subnets + peering to hub +
  default route through hub firewall (both wired via
  `terraform_remote_state` against `../vnet-hub-npd/terraform.tfstate`).
- **Run** (apply hub first so the spoke can read its state):
  ```sh
  cd terraform/vnet-hub-npd
  cp ../../variables/hub/npd/vnet.tfvars.example terraform.tfvars
  terraform init && terraform plan

  # (Apply hub, then:)
  cd ../vnet-sp01-npd
  cp ../../variables/sp01/npd/vnet.tfvars.example terraform.tfvars
  terraform init && terraform plan
  ```

## Region & subscription

- Single region: **swedencentral** (engine code `sdc`).
- Single subscription day-one:
  `883c9081-23ed-4674-95c5-45c74834e093` (pinned in every
  `.tfvars.example`). Stacks are independently variable so per-env / per-
  topology subscriptions can be introduced later without code change.

## Deletions performed

- `modules/dns/` (replaced by `modules/dnszones/`).
- `modules/log/` (replaced by `modules/loganalytics/`).
- `terraform/log/` (replaced by `log-npd` + `log-prd`).
- `modules/vnet/` (with `bastion/`, `firewall/`, `nsgrules/`) — replaced
  by `modules/network/`.

## Explicitly deferred (recorded in each feature's `spec.md`)

- **Feature 004 follow-ups (would be feature 005)**:
  - Custom NSG rules for APIM subnet (slot into
    `var.extra_nsg_rules["api-management"]`).
  - Firewall rule collections (re-introduce the rule-collection module).
  - Diagnostic-settings wiring from DNS + vnet stacks to
    `log-prd`/`log-npd` workspaces.
  - Private DNS zone vnet-links between `terraform/dns` and the hub
    vnets.
- VPN / ExpressRoute gateways, forced-tunnel firewall, hub→spoke peering
  (the reverse peer record).

## Constitution & convention compliance

- All modules are **provider-less** (Constitution VI).
- All resource names flow through `modules/naming` (Principles II, V).
  Two documented exceptions: (a) NSG canonical names are positionally
  numbered because the engine top-level catalogue doesn't yet support
  purpose-keyed naming for `nsg` — the deterministic role→name lookup
  lives in `modules/network/locals.tf`; (b) Bastion/Firewall subnets
  use Azure-mandated literals (`AzureBastionSubnet`,
  `AzureFirewallSubnet`, `AzureFirewallManagementSubnet`).
- Six-key baseline tags (`tenant`, `topology`, `environment`, `region`,
  `managed_by`, `repo`) applied uniformly via
  `modules/network/locals.tf` and the engine.
- Every root stack has a `check.subscription_pinned` and a `var.region`
  allowlist validator.
- `.tfvars` are gitignored; `.tfvars.example` templates under
  `variables/<tenant>/<env>/` are the seed copies.

## Next actions (user-owned)

1. `cp variables/<scope>/<env>/<service>.tfvars.example terraform.tfvars`
   inside each root stack, replace placeholder subscription IDs.
2. `terraform init && terraform plan` in deployment order:
   1. `terraform/log-npd`
   2. `terraform/log-prd`
   3. `terraform/dns`
   4. `terraform/vnet-hub-npd`  (must apply before spoke)
   5. `terraform/vnet-sp01-npd`
3. When happy, `terraform apply`. Then push branch:
   `git push origin master`.
