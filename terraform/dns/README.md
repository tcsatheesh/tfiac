# terraform/dns — prd-hub private DNS zones stack

Root Terraform stack that hosts the Microsoft-published private-link DNS
zone catalogue + bespoke zones for the prd hub subscription. Consumers read
`terraform_remote_state.dns.outputs.zone_ids` to provision vnet links and
private endpoints.

See [../../specs/002-private-dns-zones/spec.md](../../specs/002-private-dns-zones/spec.md)
for the contract and [../../specs/002-private-dns-zones/quickstart.md](../../specs/002-private-dns-zones/quickstart.md)
for the operator walkthrough.

## Pre-requisites

- Terraform `~> 1.9` (`1.9.x` or `1.13.x`).
- An Azure principal with **Private DNS Zone Contributor** + **Reader** at the
  target subscription (FR-029b).
- The state-backend storage account already provisioned in the same
  subscription (FR-029a). Backend fields supplied at init time via
  `-backend-config=variables/backend.hcl` — see `variables/backend.hcl.example`.

## Init

```bash
az login
az account set --subscription <prd-hub-subscription-id>

cd terraform/dns
terraform init -backend-config=../../variables/backend.hcl
```

The backend `key` is hard-coded to `hub/prd/dns.tfstate` (Constitution VII).

## Plan / apply

```bash
terraform plan  -var-file=../../variables/hub/prd/dns.tfvars.json -out=tfplan
terraform apply tfplan
```

Validation gates that fire at `plan` time (FR-031):

- `FR-001` — `topology`, `tenant`, `environment`, `region` must equal
  `hub`, `hub`, `prd`, `swc` respectively.
- `FR-016` — `custom_zones` entries must be valid FQDNs.
- `FR-017` — `custom_zones` entries must not shadow catalogue FQDNs.
- `FR-018` — `disable_catalogue_zones` entries must be valid catalogue keys.
- `FR-019` — no duplicates within `custom_zones` or `disable_catalogue_zones`.
- `FR-029` — `subscription_id` must equal the active provider's subscription.

## Outputs

The published surface is the [dns-stack contract](../../specs/002-private-dns-zones/contracts/dns-stack.md).

```hcl
data "terraform_remote_state" "dns" {
  backend = "azurerm"
  config = {
    resource_group_name  = "..."
    storage_account_name = "..."
    container_name       = "tfstate"
    key                  = "hub/prd/dns.tfstate"
  }
}

# In your spoke stack:
resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  name                  = "vnetlink-spoke01"
  resource_group_name   = data.terraform_remote_state.dns.outputs.resource_group_name
  private_dns_zone_name = data.terraform_remote_state.dns.outputs.zone_names["blob"]
  virtual_network_id    = azurerm_virtual_network.spoke.id
}
```

## Tests

Tests use `mock_provider` blocks so they require no Azure credentials:

```bash
terraform fmt -check
terraform validate
terraform test
```

The same gates run in CI on every PR (`.github/workflows/dns.yml`).
