# Quickstart — Private DNS Zones (prd-hub-only)

This is the worked example for `terraform/dns/`. Use it as the reference input for tests and as a copy-paste starter for the real `variables/prd/hub/dns.tfvars`.

## Prerequisites

- Terraform `~> 1.9`
- AzureRM provider `~> 4.0`
- Authenticated against the prd-hub subscription (`az login` or service principal env vars).
- Remote backend configured via env-injected partial config (Constitution VII).

## Reference input — `variables/prd/hub/dns.tfvars`

```hcl
subscription_id = "00000000-0000-0000-0000-000000000000"  # prd hub
region          = "uksouth"
repo            = "tcsatheesh/tfiac"

custom_zones = [
  "internal.contoso.local",
]

disable_catalogue_zones = [
  # "redis",   # uncomment to skip
]
```

## Plan

```bash
cd terraform/dns
terraform init -backend-config=...   # backend wiring is env-specific
terraform plan -var-file=../../variables/prd/hub/dns.tfvars
```

Expected plan summary on a clean subscription:

- `+ azurerm_resource_group.this` (1)
- `+ module.dnszones.azurerm_private_dns_zone.this["blob"]`
- `+ module.dnszones.azurerm_private_dns_zone.this["file"]`
- … (one per non-disabled catalogue key — 25 total at day one)
- `+ module.dnszones.azurerm_private_dns_zone.this["internal.contoso.local"]` (custom)

**Total**: 1 RG + 25 catalogue + 1 custom = 27 resources.

## Expected outputs (excerpt)

```hcl
zone_ids = {
  "blob"                     = "/subscriptions/.../privateDnsZones/privatelink.blob.core.windows.net"
  "file"                     = "/subscriptions/.../privateDnsZones/privatelink.file.core.windows.net"
  # ...
  "internal.contoso.local"   = "/subscriptions/.../privateDnsZones/internal.contoso.local"
}

zone_names = {
  "blob"                     = "privatelink.blob.core.windows.net"
  "file"                     = "privatelink.file.core.windows.net"
  # ...
  "internal.contoso.local"   = "internal.contoso.local"
}

resource_group_name = "rg-hub-prd-uks-001"
```

## Consuming from a spoke stack

```hcl
data "terraform_remote_state" "dns" {
  backend = "azurerm"
  config  = { ... }  # env-injected
}

resource "azurerm_private_endpoint" "storage_blob" {
  # ...
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [data.terraform_remote_state.dns.outputs.zone_ids["blob"]]
  }
}
```

## Common failure modes

| Symptom (Terraform error) | Root cause | Spec ref |
|---|---|---|
| `Error: subscription_pinned check failed — var.subscription_id=... but client_config=...` | Wrong Azure context (CI targets non-prd-hub sub). | FR-029 |
| `Error: private_dns_zone is prd-hub-only` (engine) | Stack instantiated with `topology != hub` or `environment != prd`. Should be impossible from `terraform/dns/` but engine guards against accidental reuse. | FR-001 / FR-006 |
| `Error: disable key "redus" not in catalogue` | Typo in `disable_catalogue_zones`. | FR-018 |
| `Error: custom_zones[2] "PRIVATELINK.BLOB.CORE.WINDOWS.NET" shadows catalogue entry "blob"` | Operator listed a catalogue FQDN under custom_zones. Disable the catalogue key instead. | FR-017 |
| `Error: custom_zones[0] "not a fqdn!" is not a valid DNS name` | FQDN regex failure. | FR-016 |
| `Error: custom_zones has duplicate entries` | Same FQDN listed twice. | FR-019 |
| `Error: region "westeurope" not in allowed_prd_hub_regions` | Region outside the platform allowlist. | OQ-003 → A |

## Running tests

```bash
cd terraform/dns
terraform test
```

Expected: 10 fixtures pass (3 positive, 6 negative, 1 determinism). Total assertions ≥ 30.

## Regenerating the determinism snapshot

After a legitimate change to `local.catalogue` or the engine `private_dns_zone` service entry:

```bash
cd terraform/dns
terraform init
echo 'jsonencode({ zone_ids = output.zone_ids, zone_names = output.zone_names })' \
  | terraform console -var-file=../../variables/prd/hub/dns.tfvars \
  | python3 -c 'import sys,json; print(json.loads(sys.stdin.read()))' \
  > tests/snapshots/reference.json
```

Commit the regenerated snapshot in the same PR as the catalogue change.
