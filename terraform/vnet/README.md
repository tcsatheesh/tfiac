# terraform/vnet/ — role-driven hub | spoke vnet stack (feature 004)

Single generic stack for **both** hub and spoke vnets. The behaviour is
selected at plan time by `var.role`:

| `role` | What gets provisioned |
|---|---|
| `hub`   | vnet + per-purpose subnets + NSGs + Azure Bastion + Azure Firewall + route table forwarding `0.0.0.0/0` to the firewall private IP + hub-side leg of every entry in `var.spoke_peerings`. |
| `spoke` | vnet + per-purpose subnets + NSGs + spoke→hub peering + default route via the hub firewall (firewall IP + hub vnet ID read from the hub stack's remote state). |

Apply order: **hub first**, each **spoke** second. Whenever a new spoke
is created, add an entry to the hub's `spoke_peerings` and re-apply the
hub — the spoke's `check.hub_peering_registered` warns until you do.

## Inputs (common)

| Var | Type | Notes |
|---|---|---|
| `subscription_id` | GUID | Pinned by `check.subscription_pinned`. |
| `region` | string | Allowlist: `swedencentral`. |
| `repo` | string | Flows into baseline tags. |
| `role` | string | `hub` or `spoke`. |
| `topology` | string | Usually equals `role`. |
| `tenant` | string | `hub`, or spoke code like `sp01`. |
| `environment` | string | `npd` / `pre` / `prd`. |
| `address_space` | `list(string)` | vnet CIDR list. |
| `subnets` | `map(string)` | Purpose → CIDR. Keys feed the engine. |

### Hub-only

- `spoke_peerings` — `map(object({ remote_vnet_id, remote_vnet_name }))`,
  default `{}`. One entry per spoke this hub should peer to. Surfaces as
  `peered_spoke_vnet_names` output.

When `role = hub`, the `subnets` map must include the canonical add-on
purposes: `bastion`, `firewall`, `firewall-mgmt`. The engine maps these
to the Azure-mandated literal names (`AzureBastionSubnet`,
`AzureFirewallSubnet`, `AzureFirewallManagementSubnet`).

### Spoke-only

- `hub_state_backend` — `object({ resource_group_name, storage_account_name, container_name, key })`.
  Locates the hub's tfstate. The spoke reads `vnet_id`,
  `firewall_private_ip`, and `peered_spoke_vnet_names` from it.
- `hub_vnet_id_override`, `hub_firewall_private_ip_override`,
  `hub_peered_spoke_vnet_names_override` — test seams that skip
  `terraform_remote_state`. Never set them in real `.tfvars`.

Reference templates:
[`variables/npd/hub/vnet.tfvars.example`](../../variables/npd/hub/vnet.tfvars.example),
[`variables/npd/sp01/vnet.tfvars.example`](../../variables/npd/sp01/vnet.tfvars.example).

## Outputs

| Output | Hub | Spoke |
|---|---|---|
| `vnet_id`, `vnet_name`, `resource_group_name`, `subnet_ids`, `subnet_names` | ✓ | ✓ |
| `firewall_private_ip` | ✓ | `null` |
| `peered_spoke_vnet_names` | ✓ | `null` |
| `peering_enabled` | `null` | `true` if spoke→hub peer created |

## Run

```sh
cd terraform/vnet

# --- hub ---
terraform init -reconfigure \
  -backend-config=../../variables/backend.hcl \
  -backend-config="key=npd/hub/vnet.tfstate"
terraform plan -var-file=../../variables/npd/hub/vnet.tfvars

# --- spoke (after hub apply) ---
terraform init -reconfigure \
  -backend-config=../../variables/backend.hcl \
  -backend-config="key=npd/sp01/vnet.tfstate"
terraform plan -var-file=../../variables/npd/sp01/vnet.tfvars
```

## Tests

```sh
cd terraform/vnet && terraform init -backend=false && terraform test
```

6 tests: hub baseline + spoke-peering registration, spoke baseline,
unregistered-spoke warning, disallowed region, subscription mismatch.
