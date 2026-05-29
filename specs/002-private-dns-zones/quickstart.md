# Quickstart — `terraform/dns/` stack

Operator-facing walkthrough for the prd-hub apply and the consumer experience.

## 1 · Inputs (`variables/hub/prd/dns.tfvars.json`)

```json
{
  "subscription_id": "00000000-0000-0000-0000-000000000000",
  "region": "swc",
  "repo": "tcsatheesh/tfiac",
  "topology": "hub",
  "tenant": "hub",
  "environment": "prd",
  "custom_zones": [],
  "disable_catalogue_zones": []
}
```

Notes:
- `region` MUST be `"swc"` (FR-001, DNS-INV-9).
- `topology` MUST be `"hub"` and `environment` MUST be `"prd"` (DNS-INV-9).
- `custom_zones` and `disable_catalogue_zones` start empty; populate as platform needs grow.

## 2 · First-time apply (interactive admin, v1 — FR-029b)

```bash
# 1. Authenticate as a human admin with at least:
#    - "Private DNS Zone Contributor" at subscription scope
#    - "Reader" at subscription scope
az login
az account set --subscription "<subscription-id>"

# 2. Initialise with backend pointing at the prd-hub state account
cd terraform/dns
terraform init \
  -backend-config="resource_group_name=<state-rg>" \
  -backend-config="storage_account_name=<state-sa>" \
  -backend-config="container_name=<state-container>"
  # key="hub/prd/dns.tfstate" is hard-coded in backend.tf (Constitution VII)

# 3. Plan + apply
terraform plan -var-file=../../variables/hub/prd/dns.tfvars.json -out=tfplan
terraform apply tfplan
```

Pipeline OIDC is a follow-up; see spec §"Out of Scope" and research.md D12.

## 3 · Consumer usage (from any downstream stack)

```hcl
data "terraform_remote_state" "dns" {
  backend = "azurerm"
  config = {
    resource_group_name  = "<state-rg>"
    storage_account_name = "<state-sa>"
    container_name       = "<state-container>"
    key                  = "hub/prd/dns.tfstate"
  }
}

# Look up a zone id by catalogue key
locals {
  blob_zone_id = data.terraform_remote_state.dns.outputs.zone_ids["blob"]
}
```

See [contracts/dns-stack.md](contracts/dns-stack.md) for the full consumer surface.

## 4 · Determinism check (SC-002 / SC-007)

```bash
# Run A — input ordering 1
cp variables/hub/prd/dns.tfvars.json /tmp/a.tfvars.json
terraform plan -var-file=/tmp/a.tfvars.json -out=/tmp/plan.a
terraform show -json /tmp/plan.a | jq '.planned_values.outputs.zone_ids.value' > /tmp/zone_ids.a

# Run B — same inputs in different list order
jq '.custom_zones |= reverse | .disable_catalogue_zones |= reverse' /tmp/a.tfvars.json > /tmp/b.tfvars.json
terraform plan -var-file=/tmp/b.tfvars.json -out=/tmp/plan.b
terraform show -json /tmp/plan.b | jq '.planned_values.outputs.zone_ids.value' > /tmp/zone_ids.b

diff /tmp/zone_ids.a /tmp/zone_ids.b   # MUST be empty
```

## 5 · Migration from legacy `terraform/dns/`

*N/A in v1* — no legacy stack exists in this repo. Reserved for a future feature.

## 6 · Run tests

```bash
# Module-level
cd modules/dnszones
terraform init -backend=false
terraform test           # all 9 *.tftest.hcl files must pass

# Stack-level
cd ../../terraform/dns
terraform init -backend=false
terraform test           # plan-snapshot and subscription-mismatch
```

## 7 · Adding a new catalogue zone (PR workflow)

1. Append a new `(key, fqdn)` row to `modules/dnszones/catalogue.tf`.
2. Regenerate the snapshot fixtures manually:

   ```bash
   cd terraform/dns
   terraform plan -out=ref.plan -var-file=../../variables/hub/prd/dns.tfvars.json
   terraform show -json ref.plan | jq '.planned_values.outputs.zone_ids.value'   > ../../modules/dnszones/tests/fixtures/zone_ids_snapshot.json
   terraform show -json ref.plan | jq '.planned_values.outputs.zone_names.value' > ../../modules/dnszones/tests/fixtures/zone_names_snapshot.json
   ```

3. Update [contracts/dns-stack.md](contracts/dns-stack.md) "Compatibility" notes if needed.
4. Open PR; CI runs the catalogue completeness + determinism tests.

## 8 · Adding a custom zone

Append to `custom_zones` in `variables/hub/prd/dns.tfvars.json`. The FR-016 regex and FR-017 anti-shadow check fire at plan time; no test changes required.
