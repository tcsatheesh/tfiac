# Quickstart: Naming Convention Engine

This is the minimum a consumer needs to know to use `modules/naming`.

## 1. Add the module

```hcl
# terraform/<stack>/main.tf

module "names" {
  source = "../../modules/naming"

  input = {
    tenant        = "hub"
    environment   = "prd"
    region        = "uks"
    usecase       = "shd"
    stack_purpose = "svc"
    repo          = "tcsatheesh/tfiac"
  }

  services = [
    { service_type = "resource_group", key = "main" },
    { service_type = "log_analytics",  service_purpose = "lgs", key = "primary" },
    { service_type = "storage",        service_purpose = "lgs", key = "audit" },
    { service_type = "keyvault",       service_purpose = "app", key = "primary" },
    { service_type = "vnet",           service_purpose = "net", key = "core" },
  ]

  children = [
    { service_type = "subnet",       parent_key = "core", child_purpose = "app",   key = "app" },
    { service_type = "subnet",       parent_key = "core", child_purpose = "pep",   key = "pep" },
    { service_type = "vnet_bastion", parent_key = "core", key = "bas" },
  ]

  extra_tags = {
    cost_center = "PLT-001"
    owner       = "platform-team"
  }
}
```

## 2. Consume the output

```hcl
resource "azurerm_resource_group" "this" {
  for_each = { for k, v in module.names.names : k => v if v.service_type == "resource_group" }

  name     = each.key
  location = "uksouth"  # or look up via your own region-full var
  tags     = each.value.tags
}

# Similarly for other resource types: filter by service_type and iterate.
```

## 3. Verify determinism

```bash
terraform init
terraform plan -out tfplan
terraform show -json tfplan > plan1.json

# rearrange the `services` list in main.tf (do NOT change any values)

terraform plan -out tfplan
terraform show -json tfplan > plan2.json

diff plan1.json plan2.json  # MUST be empty
```

## 4. Run the engine's own tests

```bash
cd modules/naming
terraform init -backend=false
terraform test
```

Expected output: all `*.tftest.hcl` files pass.

## 5. Common failures

| Symptom                                                       | Likely cause                                                        |
|---------------------------------------------------------------|---------------------------------------------------------------------|
| `Error: unknown service_type "foo"`                           | The `service_type` isn't in the spec table / catalogue. Add a row.  |
| `Error: duplicate key "primary" in (storage, lgs)`            | Two entries share the same key in the same group; rename one.       |
| `Error: name "kv...001" exceeds azure_max 24`                 | Inputs combined wider than the worst-case sizing; recheck regexes.  |
| `Error: extra_tags collides with baseline key "environment"`  | Remove that key from `var.extra_tags` (you can't override baseline).|
| `Error: rg entry forbids service_purpose`                     | Drop `service_purpose` from RG entries.                             |
