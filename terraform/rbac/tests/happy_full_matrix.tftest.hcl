# VC-30 / VC-32 — full portal-matching matrix. aifoundry account + project, two
# storages (agent + account/user-owned, distinct purposes), search, cosmos and
# key vault, both toggles on. Asserts the EXACT grant counts and that each
# storage grant lands on the purpose-correct storage.

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  services_state_backend = {
    resource_group_name  = "rg-tfs-shd-hub-npd-swc-001"
    storage_account_name = "sttfsshdhubnpdswc001"
    container_name       = "tfstate"
    key                  = "sp01/dev/services.tfstate"
  }
  enable_aifoundry_user_owned_storage  = true
  enable_aifoundry_keyvault_connection = true
  enable_project_acr_pull              = true
  agent_storage_purpose                = "agt"
  account_storage_purpose              = "act"
}

mock_provider "azurerm" {}
mock_provider "azapi" {}

override_data {
  target = data.terraform_remote_state.services
  values = {
    outputs = {
      naming = {
        acct  = { service_type = "aifoundry", service_purpose = "fdy" }
        proj  = { service_type = "aifoundry_project", service_purpose = "prj" }
        kv    = { service_type = "keyvault", service_purpose = "kvt" }
        srch  = { service_type = "search", service_purpose = "srch" }
        cos   = { service_type = "cosmosdb", service_purpose = "cos" }
        stagt = { service_type = "storage", service_purpose = "agt" }
        stact = { service_type = "storage", service_purpose = "act" }
        acr   = { service_type = "container_registry", service_purpose = "acr" }
      }
      resource_ids = {
        acct  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.CognitiveServices/accounts/acct"
        proj  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.CognitiveServices/accounts/acct/projects/proj"
        kv    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.KeyVault/vaults/kv"
        srch  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Search/searchServices/srch"
        cos   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.DocumentDB/databaseAccounts/cos"
        stagt = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/stagt"
        stact = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/stact"
        acr   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.ContainerRegistry/registries/acr"
      }
      resource_group_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg"
    }
  }
}

override_data {
  target = data.azapi_resource.account[0]
  values = {
    output = { identity = { principalId = "11111111-1111-1111-1111-111111111111" } }
  }
}

override_data {
  target = data.azapi_resource.project[0]
  values = {
    output = { identity = { principalId = "22222222-2222-2222-2222-222222222222" } }
  }
}

run "full_matrix" {
  command = plan

  # 2 account-KV + 1 account-RG + 1 account-UOS + 3 project-storage + 2
  # project-search + 2 project-cosmos + 1 project-acr = 12 control-plane grants.
  assert {
    condition     = length(output.role_assignment_ids) == 12
    error_message = "Expected exactly 12 control-plane role assignments for the full portal-matching matrix incl. AcrPull (VC-30 / FR-064)."
  }

  assert {
    condition     = length(output.cosmos_sql_role_assignment_ids) == 1
    error_message = "Expected exactly one Cosmos DB data-plane SQL role assignment (FR-057)."
  }

  # Every expected grant key present.
  assert {
    condition = length(setsubtract([
      "account-kv-secrets-officer",
      "account-kv-crypto-user",
      "account-rg-contributor",
      "account-uos-storage-blob-data-contributor",
      "project-agent-storage-blob-data-contributor",
      "project-agent-storage-blob-data-owner",
      "project-agent-storage-file-priv-contributor",
      "project-search-index-data-contributor",
      "project-search-service-contributor",
      "project-cosmos-operator",
      "project-cosmos-documentdb-account-contributor",
      "project-acr-pull",
    ], keys(output.role_assignment_ids))) == 0
    error_message = "VC-30: the full grant key set must be present."
  }

  # VC-36 — the account-MI Key Vault grant carries the Key Vault Secrets Officer
  # role GUID (b86a8fe4-…), corrected from the FR-046 mislabel.
  assert {
    condition     = endswith(output.grant_role_definition_ids["account-kv-secrets-officer"], "/b86a8fe4-44ce-4948-aee5-eccb2c155cd7")
    error_message = "VC-36: account-kv-secrets-officer must use the Key Vault Secrets Officer role GUID b86a8fe4-44ce-4948-aee5-eccb2c155cd7."
  }

  # VC-32 — purpose-correct storage resolution. The account user-owned grant must
  # land on the 'act' storage; the project agent grants on the 'agt' storage.
  assert {
    condition     = output.grant_scopes["account-uos-storage-blob-data-contributor"] == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/stact"
    error_message = "VC-32: account user-owned grant must be scoped to the account_storage_purpose ('act') storage."
  }

  assert {
    condition     = output.grant_scopes["project-agent-storage-blob-data-contributor"] == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/stagt"
    error_message = "VC-32: project agent grant must be scoped to the agent_storage_purpose ('agt') storage."
  }

  # KV grants scoped to the key vault.
  assert {
    condition     = output.grant_scopes["account-kv-crypto-user"] == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.KeyVault/vaults/kv"
    error_message = "FR-047: KV Crypto User grant must be scoped to the key vault."
  }

  # FR-064 — the project AcrPull grant is scoped to the container registry and
  # carries the AcrPull role GUID (7f951dda-…).
  assert {
    condition     = output.grant_scopes["project-acr-pull"] == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.ContainerRegistry/registries/acr"
    error_message = "FR-064: project-acr-pull must be scoped to the container registry."
  }

  assert {
    condition     = endswith(output.grant_role_definition_ids["project-acr-pull"], "/7f951dda-4ed3-4680-a7ca-43fe172d538d")
    error_message = "FR-064: project-acr-pull must use the AcrPull role GUID 7f951dda-4ed3-4680-a7ca-43fe172d538d."
  }
}
