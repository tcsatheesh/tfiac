# Delivery Summary — Features 002 / 003 / 004 + flat-stack restructure

The repo is organised as a small set of **generic root stacks** under
`terraform/`, each switchable across env / tenant / role via
`variables/<env>/<scope>/<service>.tfvars`. Pre-feature-001 modules and
stacks are parked under `terraform/_legacy/` and `modules/` (untouched).

## Repository layout

```
terraform/
├── bootstrap/         LOCAL backend; creates the tfstate storage account
├── dns/               azurerm backend; Private DNS catalogue (feature 002)
├── log/               azurerm backend; Log Analytics workspace (feature 003)
├── vnet/              azurerm backend; role-driven hub|spoke vnet (feature 004)
└── _legacy/           pre-feature-001 stacks (parked, not deleted)

variables/
├── backend.hcl.example         shared azurerm backend snippet (per-stack `key=`)
├── bootstrap.tfvars.example    inputs for terraform/bootstrap/
├── npd/
│   ├── hub/
│   │   ├── log.tfvars.example
│   │   └── vnet.tfvars.example
│   └── sp01/
│       └── vnet.tfvars.example
└── prd/
    └── hub/
        ├── dns.tfvars.example
        └── log.tfvars.example
```

## Test inventory (all green)

| Stack | Pass | Fail |
|---|---|---|
| `modules/naming` | 41 | 0 |
| `terraform/bootstrap` | 1 | 0 |
| `terraform/dns` | 13 | 0 |
| `terraform/log` | 4 | 0 |
| `terraform/vnet` | 6 | 0 |
| **Total** | **65** | **0** |

Re-run anywhere:

```sh
for d in modules/naming terraform/bootstrap terraform/dns terraform/log terraform/vnet; do
  echo "### $d"
  (cd "$d" && terraform init -backend=false -upgrade >/dev/null && terraform test)
done
```

## Remote-state convention

- Single Azure Storage container `tfstate` provisioned by
  `terraform/bootstrap/`.
- State key per stack: `<env>/<scope>/<service>.tfstate`
  e.g. `prd/hub/dns.tfstate`, `npd/hub/vnet.tfstate`, `npd/sp01/vnet.tfstate`.
- Stacks use the partial azurerm backend (`backend "azurerm" {}`).
  Configure at init time:
  ```sh
  terraform init -reconfigure \
    -backend-config=../../variables/backend.hcl \
    -backend-config="key=<env>/<scope>/<service>.tfstate"
  ```
- Spoke vnet reads hub vnet outputs via `terraform_remote_state` —
  configured through `var.hub_state_backend` in the spoke's tfvars.

## Secrets handling

`subscription_id` and `repo` are **never** written to any `*.tfvars` (the
examples deliberately omit them). They live in the repo-root `.env`
(gitignored; template at `.env.example`) and are injected at plan time:

```sh
set -a; . .env; set +a

terraform plan \
  -var-file=../../variables/<env>/<scope>/<service>.tfvars \
  -var "subscription_id=$SUBSCRIPTION_ID_<ENV>_<SCOPE>" \
  -var "repo=$GITHUB_ORGANIZATION/$GITHUB_REPOSITORY"
```

See each stack's README for the canonical command.

## Run order

1. **`terraform/bootstrap/`** — once per subscription. Capture
   `backend_config_snippet` output into `variables/backend.hcl`.
2. **`terraform/log/`** (npd/hub, prd/hub) — per `(env, scope)`.
3. **`terraform/dns/`** (prd/hub day-one) — depends on nothing.
4. **`terraform/vnet/`** with `role=hub` (per env) — must apply before any
   spoke.
5. **`terraform/vnet/`** with `role=spoke` (per spoke tenant + env).
6. After a new spoke exists, append it to the matching hub tfvars'
   `spoke_peerings` map and re-apply the hub.

## Feature 002 — Private DNS

- Module: `modules/dnszones/`
- Stack: `terraform/dns/` (generic; first deployment is prd/hub).
- 25 day-one catalogue zones + N operator FQDNs, all named via the
  naming engine (`pdnsz-…`).
- Failure modes documented in [`terraform/dns/README.md`](../terraform/dns/README.md).

## Feature 003 — Centralized Log Analytics

- Module: `modules/loganalytics/`
- Stack: `terraform/log/` (generic; npd/hub + prd/hub day-one consumers).
- Workspace: `log-<tenant>-<env>-sdc-001`, retention 30 d, SKU `PerGB2018`.
- Consumer pattern documented in [`terraform/log/README.md`](../terraform/log/README.md).

## Feature 004 — Hub & Spoke Network

- Module: `modules/network/` + sub-modules `bastion/`, `firewall/`.
- Stack: `terraform/vnet/`. **One** stack folder, switched by `var.role`:
  - `role = hub` provisions vnet + NSGs + Bastion + Firewall + route table
    + hub-side leg of every `spoke_peerings` entry.
  - `role = spoke` provisions vnet + NSGs + spoke→hub peering + default
    route via the hub firewall (firewall IP + hub vnet ID + registered
    spoke list pulled from the hub's remote state).
- Subnet role catalogue: `development`, `pre-production`, `api-management`,
  `buildsvr`, `bastion`, `firewall`, `firewall-mgmt`, `function-app`,
  `logic-app`, `preprod-func`, `preprod-logic`.

## Region & subscription

- Single region day-one: **swedencentral** (`region_code = sdc`).
- Subscription IDs live in the repo-root `.env` (gitignored;
  template at `.env.example`) and are injected at plan time via
  `-var subscription_id=...`. Stacks are independently variable, so
  per-env / per-topology subscriptions can be introduced without code
  change \u2014 add a new key to `.env.example` and reference it from the
  stack's `terraform plan` command.

## Constitution & convention compliance

- All modules are **provider-less** (Constitution VI).
- All resource names flow through `modules/naming` (Principles II, V).
  Documented exceptions: (a) NSG canonical names are positionally
  numbered; (b) Bastion/Firewall subnets use Azure-mandated literals.
- Six-key baseline tags (`tenant`, `topology`, `environment`, `region`,
  `managed_by`, `repo`) applied via engine + `modules/network/locals.tf`.
- Every root stack has a `check.subscription_pinned` and a `var.region`
  allowlist validator.
- `.tfvars` are gitignored; `.tfvars.example` templates under
  `variables/<env>/<scope>/` are the seed copies.

## Explicitly deferred

- Diagnostic-settings wiring from DNS + vnet stacks to the
  `log` workspaces.
- Private DNS zone vnet-links between `terraform/dns` and the hub vnets.
- Custom NSG rule sets for APIM subnet.
- Firewall rule collections (re-introduce the rule-collection module).
- VPN / ExpressRoute gateways, forced-tunnel firewall.
