# Quickstart — Feature 006 — Services

**Audience**: operators who want to deploy a `purpose=svc` resource group
plus a selectable set of Azure services into a hub or spoke subscription.

**Status**: regenerated 2026-05-30 against the actual engine surface. Every
canonical name, input field, and command below is verified against
[modules/naming/](../../modules/naming/) and the C-001 selectable inventory
in [spec.md](spec.md#clarifications).

---

## Prerequisites

1. **Bootstrap stack already applied** for the target
   `(tenant, environment)`:
   - `terraform/bootstrap/` has provisioned the hub-internal state SA.
   - The deploying OIDC SP holds `Contributor` at subscription scope.
2. **Azure CLI logged in** to the destination subscription
   (`az account show` returns the right subscription ID), OR the GitHub
   Actions runner uses the existing OIDC federation.
3. **State-SA firewall** allows your runner / shell IP (the deploy workflow
   handles this in CI; locally, follow the same temporary-allowlist
   pattern as `terraform/vnet/`).

---

## Step 1 — Author `services.tfvars.json`

Edit (or create) `variables/<tenant>/<environment>/services.tfvars.json`.
Reference values for a spoke deployment:

```json
{
  "subscription_id": "REPLACE-WITH-RUNTIME-SUBSCRIPTION-ID",
  "topology":        "spoke",
  "tenant":          "sp01",
  "environment":     "npd",
  "region":          "uks",
  "usecase":         "shd",
  "repo":            "tcsatheesh/tfiac",

  "services": [
    { "type": "keyvault" },
    { "type": "storage",  "count": 2 },
    { "type": "log_analytics" }
  ],

  "overrides": {
    "kvshdshdsp01npduks001": { "sku_name": "premium" }
  }
}
```

Notes:
- **`subscription_id`** is committed as the literal placeholder; the stack's
  regex validation rejects it. The runtime injection step (below) replaces
  it.
- **`usecase`** is **required** ([spec.md CA-002](spec.md#ca-002--usecase-is-the-8th-required-stack-input-corrects-fr-001-a2a5)).
  Day-one value is `"shd"`. The stack validates `usecase` against
  `^[a-z0-9]{3}$` (exactly 3 chars) — tighter than the engine's
  `^[a-z0-9]{3,4}$` — so that the CA-004 strategy-B `service_purpose`
  fallback always satisfies the engine's `^[a-z0-9]{3}$` regex.
- **`topology`** = `"spoke"` implies `tenant` matches `^sp[0-9]{2}$`;
  `topology` = `"hub"` implies `tenant == "hub"` (stack-side cross-check
  per [CA-003](spec.md#ca-003--topology-gating-is-stack-owned-corrects-fr-003-cross-check-fr-007-fr-018-edge-cases)).
- **`overrides`** keys MUST be canonical names. Reference shape table in
  [data-model.md § 5](data-model.md). Get them wrong and `terraform plan`
  hard-fails with the "unmatched override key" message
  ([CA-006](spec.md#ca-006--stack-owns-unmatched-overrides-hard-fail-corrects-fr-006-fr-018-c-003)).
- **The `svc` resource group is NOT declared** — the stack emits it
  automatically. Adding `{ "type": "resource_group" }` is forbidden and is
  caught by the C-001 allowlist.

---

## Step 2 — Inject `subscription_id` at runtime

Either of the two Terraform-native paths is accepted
([CA-011](spec.md#ca-011--subscription_id-runtime-injection-cli-or-env-corrects-c-005-quickstart-troubleshooting)):

**Local shell (env var)**:

```bash
export TF_VAR_subscription_id="00000000-0000-0000-0000-000000000000"
```

**CI or one-shot CLI (CLI flag)** — this is the form
`.github/workflows/deploy.yaml` uses:

```bash
terraform plan -var "subscription_id=$AZURE_SUBSCRIPTION_ID" \
  -var-file=../../variables/sp01/dev/services.tfvars.json
```

Either path overrides the committed placeholder. The stack's
`variable "subscription_id"` validation hard-fails at plan time if the
placeholder is still in effect after the override, and a `check
"subscription_match"` block cross-verifies against
`data.azurerm_client_config.current.subscription_id`.

---

## Step 3 — Initialise the backend

```bash
cd terraform/services
terraform init \
  -backend-config="resource_group_name=$STATE_RG" \
  -backend-config="storage_account_name=$STATE_SA" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=sp01/dev/services.tfstate" \
  -backend-config="subscription_id=$HUB_SUBSCRIPTION_ID"
```

State key follows `"{tenant}/{environment}/services.tfstate"`
([spec.md C-006](spec.md#clarifications)), mirroring `terraform/vnet/`.

---

## Step 4 — Plan

```bash
terraform plan -var-file=../../variables/sp01/dev/services.tfvars.json
```

Expected plan output for the reference input above (`subscription_id` set
via env or CLI):

```
Terraform will perform the following actions:

  # azurerm_resource_group.svc will be created
  + resource "azurerm_resource_group" "svc" {
      + name     = "rg-svc-shd-sp01-npd-uks-001"
      + location = "uksouth"
      + tags     = { ... 8 baseline tags ... }
    }

  # module.keyvault["kvshdshdsp01npduks001"]...
  + ... name = "kvshdshdsp01npduks001" ...
  # module.storage["stshdshdsp01npduks001"]
  + ... name = "stshdshdsp01npduks001" ...
  # module.storage["stshdshdsp01npduks002"]
  + ... name = "stshdshdsp01npduks002" ...
  # module.log_analytics["log-shd-shd-sp01-npd-uks-001"]
  + ... name = "log-shd-shd-sp01-npd-uks-001" ...

Plan: 5 to add, 0 to change, 0 to destroy.
```

A second `terraform plan` against unchanged inputs reports **0 to add, 0 to
change, 0 to destroy** ([SC-002](spec.md#measurable-outcomes)).

---

## Step 5 — Apply

```bash
terraform apply -var-file=../../variables/sp01/dev/services.tfvars.json
```

After apply, all resources land in the single `rg-svc-shd-sp01-npd-uks-001`
RG.

---

## Hub variant

Identical workflow, with three edits to `services.tfvars.json`:

```json
{
  "topology": "hub",
  "tenant":   "hub",
  "services": [
    { "type": "keyvault" },
    { "type": "log_analytics" }
  ]
}
```

Resulting RG: `rg-svc-shd-hub-npd-uks-001`.

---

## Adding a service (day-2 flow — US3)

Add one entry to `services` and re-plan:

```diff
   "services": [
     { "type": "keyvault" },
     { "type": "storage",  "count": 2 },
-    { "type": "log_analytics" }
+    { "type": "log_analytics" },
+    { "type": "search" }
   ]
```

Plan: **1 to add, 0 to change, 0 to destroy.** The new resource is
`srch-shd-shd-sp01-npd-uks-001`.

---

## Overriding one instance (US4)

```json
"overrides": {
  "kvshdshdsp01npduks001": { "sku_name": "premium" }
}
```

With two keyvaults in `services` (`{ "type": "keyvault", "count": 2 }`),
instance `001` carries `premium` and instance `002` carries the wrapper's
default (`standard`). Plan shows one update, zero adds, zero destroys.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `subscription_id must be a lowercase Azure subscription GUID` | Placeholder still in effect. | Set `TF_VAR_subscription_id` OR pass `-var "subscription_id=..."`. |
| `VNET-INV-4`-style `subscription_match` check failure (we use the same idiom) | Provider-bound subscription differs from `var.subscription_id`. | Re-run `az login` against the intended subscription, OR fix the value being injected. |
| `service type "..." is deferred` | Selected type is in the engine catalogue but excluded from v1 ([C-001](spec.md#clarifications)). | Pick from the 15-type C-001 allowlist OR open a follow-up. |
| `service type "..." is owned by terraform/dns/` (or similar) | Selected a type owned by another stack (`dns_zone`, `private_dns_zone`, `vnet`, etc.). | Deploy via the owning stack. |
| `private_endpoints deferred to follow-up` | `private_endpoints` populated on a `services[]` entry. | Remove until A4 lifts. |
| `unmatched override key: kv...001` | `overrides` map key does not equal any emitted canonical name. | Cross-reference [data-model.md § 5](data-model.md). |
| INV-4 / INV-6 / INV-7 engine errors | Internal bug (the stack's expansion in `local.engine_services` should never produce these). | Open a bug; attach the failing `services.tfvars.json`. |

---

## What this stack does NOT do

See [spec.md § Out of Scope](spec.md). Notably: no private endpoints, no
diagnostic settings, no CMK, no locks, no RBAC role assignments (those live
in `terraform/rbac/`), no DNS zones (those live in `terraform/dns/`), no
VNets / subnets / NSGs (those live in `terraform/vnet/`).
