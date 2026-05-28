# terraform/vnet-sp01-npd/

Feature 004 — npd sp01 spoke vnet stack. Provisions vnet
`vnet-sp01-npd-sdc-001` (`10.240.2.0/24`) with 6 subnets, per-subnet
NSGs, a route table that forwards `0.0.0.0/0` to the hub firewall, and
a vnet peering to `vnet-hub-npd-sdc-001`.

Hub coupling: reads `vnet_id`, `firewall_private_ip`, and
`peered_spoke_vnet_names` via `terraform_remote_state` against
`../vnet-hub-npd/terraform.tfstate`. For tests, all three may be
supplied as variables.

## ⚠️ Peering ownership (split-ownership model)

The hub<->spoke peering is **two resources, one per side**:

| Leg | Lives in | Created by |
|---|---|---|
| `spoke -> hub` | this stack | `azurerm_virtual_network_peering.spoke_to_hub` |
| `hub -> spoke` | `terraform/vnet-hub-npd/` | `azurerm_virtual_network_peering.hub_to_spoke["sp01-npd"]` (via `var.spoke_peerings`) |

**When you create a new spoke stack you MUST:**

1. Apply the spoke first (creates spoke->hub leg).
2. Add an entry to the hub stack's `var.spoke_peerings` (see
   [variables/hub/npd/vnet.tfvars.example](../../variables/hub/npd/vnet.tfvars.example)):

   ```hcl
   spoke_peerings = {
     "sp01-npd" = {
       remote_vnet_id   = "<spoke vnet id>"
       remote_vnet_name = "vnet-sp01-npd-sdc-001"
     }
   }
   ```
3. Re-apply the hub stack (creates hub->spoke leg).

The spoke stack's `check.hub_peering_registered` block emits a Terraform
**warning** on every `plan`/`apply` until step 3 is done — it cross-
checks this spoke's vnet name against the hub's `peered_spoke_vnet_names`
output. The check never fails the plan (peering is async; a missing hub
leg won't break the spoke apply), but it makes the gap impossible to
miss.

```sh
cd terraform/vnet-sp01-npd && terraform test
```
