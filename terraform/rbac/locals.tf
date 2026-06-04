locals {
  # ---- Consumed services remote state ----------------------------------------
  naming         = data.terraform_remote_state.services.outputs.naming
  resource_ids   = data.terraform_remote_state.services.outputs.resource_ids
  services_rg_id = data.terraform_remote_state.services.outputs.resource_group_id

  # ---- Target canonical names (by service_type / service_purpose) ------------
  # All resolved from the engine's `naming` map — never by hard-coded names
  # (FR-058). Each *_name is null when the service is absent from the stack.
  account_name  = one([for k, v in local.naming : k if v.service_type == "aifoundry"])
  project_name  = one([for k, v in local.naming : k if v.service_type == "aifoundry_project"])
  keyvault_name = one([for k, v in local.naming : k if v.service_type == "keyvault"])
  search_name   = one([for k, v in local.naming : k if v.service_type == "search"])
  cosmos_name   = one([for k, v in local.naming : k if v.service_type == "cosmosdb"])

  # Agent storage: filter by purpose when set; otherwise fall back to the single
  # storage when exactly one is present (null when ambiguous/absent).
  storage_names = [for k, v in local.naming : k if v.service_type == "storage"]
  agent_storage_name = var.agent_storage_purpose != null ? one([
    for k, v in local.naming : k
    if v.service_type == "storage" && v.service_purpose == var.agent_storage_purpose
  ]) : (length(local.storage_names) == 1 ? local.storage_names[0] : null)

  # Account/user-owned storage: resolved by purpose only (the two-storage case).
  account_storage_name = var.account_storage_purpose != null ? one([
    for k, v in local.naming : k
    if v.service_type == "storage" && v.service_purpose == var.account_storage_purpose
  ]) : null

  # ---- Presence (all known at plan from the remote state) --------------------
  account_present         = local.account_name != null
  project_present         = local.project_name != null
  keyvault_present        = local.keyvault_name != null
  search_present          = local.search_name != null
  cosmos_present          = local.cosmos_name != null
  agent_storage_present   = local.agent_storage_name != null
  account_storage_present = local.account_storage_name != null

  # ---- Target resource ids ---------------------------------------------------
  account_id         = local.account_present ? local.resource_ids[local.account_name] : null
  project_id         = local.project_present ? local.resource_ids[local.project_name] : null
  keyvault_id        = local.keyvault_present ? local.resource_ids[local.keyvault_name] : null
  search_id          = local.search_present ? local.resource_ids[local.search_name] : null
  cosmos_id          = local.cosmos_present ? local.resource_ids[local.cosmos_name] : null
  agent_storage_id   = local.agent_storage_present ? local.resource_ids[local.agent_storage_name] : null
  account_storage_id = local.account_storage_present ? local.resource_ids[local.account_storage_name] : null

  # ---- Principal ids (computed at apply; C-062) ------------------------------
  account_principal_id = local.account_present ? data.azapi_resource.account[0].output.identity.principalId : null
  project_principal_id = local.project_present ? data.azapi_resource.project[0].output.identity.principalId : null

  # ---- Role-definition GUIDs (verbatim from the portal template) -------------
  role_guids = {
    kv_secrets_officer             = "b86a8fe4-44ce-4948-aee5-eccb2c155cd7" # FR-046 (Key Vault Secrets Officer)
    kv_crypto_user                 = "f25e0fa2-a7c8-4377-a976-54943a77a395" # FR-047
    contributor                    = "b24988ac-6180-42a0-ab88-20f7382dd24c" # FR-048
    storage_blob_data_contributor  = "ba92f5b4-2d11-453d-a403-e96b0029c9fe" # FR-049/FR-050
    storage_blob_data_owner        = "b7e6dc6d-f1e8-4753-8033-0f276bb0955b" # FR-051
    storage_file_priv_contributor  = "974c5e8b-45b9-4653-ba55-5f855dd0fb88" # FR-052
    search_index_data_contributor  = "8ebe5a00-799e-43f5-93ac-243d3dce84a7" # FR-053
    search_service_contributor     = "7ca78c08-252a-4471-8644-bb5ff32d4ba0" # FR-054
    cosmos_operator                = "230815da-be43-4aae-9cb4-875f7bd000aa" # FR-055
    documentdb_account_contributor = "5bd9cd88-fe45-4216-938b-f97437e15450" # FR-056
  }

  role_def_prefix = "/subscriptions/${var.subscription_id}/providers/Microsoft.Authorization/roleDefinitions"
  role_def_ids    = { for k, g in local.role_guids : k => "${local.role_def_prefix}/${g}" }

  # Cosmos DB Built-in Data Contributor (FR-057) — data-plane SQL role. null when
  # no cosmos is present (avoids a null string interpolation).
  cosmos_sql_data_contributor_role_id = local.cosmos_present ? "${local.cosmos_id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002" : null

  # ---- Resolved toggle gates (known at plan) ---------------------------------
  account_kv_grant_enabled  = local.account_present && local.keyvault_present && var.enable_aifoundry_keyvault_connection
  account_uos_grant_enabled = local.account_present && local.account_storage_present && var.enable_aifoundry_user_owned_storage
  project_storage_enabled   = local.project_present && local.agent_storage_present
  project_search_enabled    = local.project_present && local.search_present
  project_cosmos_enabled    = local.project_present && local.cosmos_present

  # ---- Control-plane role-assignment fan-out ---------------------------------
  role_assignments = merge(
    # Account MI — Key Vault Secrets Officer + Crypto User grants (FR-046 / FR-047)
    local.account_kv_grant_enabled ? {
      account-kv-secrets-officer = {
        scope_id           = local.keyvault_id
        role_definition_id = local.role_def_ids.kv_secrets_officer
        principal_id       = local.account_principal_id
        principal_type     = "ServicePrincipal"
      }
      account-kv-crypto-user = {
        scope_id           = local.keyvault_id
        role_definition_id = local.role_def_ids.kv_crypto_user
        principal_id       = local.account_principal_id
        principal_type     = "ServicePrincipal"
      }
    } : {},

    # Account MI — Contributor on the services resource group (FR-048)
    local.account_present ? {
      account-rg-contributor = {
        scope_id           = local.services_rg_id
        role_definition_id = local.role_def_ids.contributor
        principal_id       = local.account_principal_id
        principal_type     = "ServicePrincipal"
      }
    } : {},

    # Account MI — Storage Blob Data Contributor on user-owned storage (FR-049)
    local.account_uos_grant_enabled ? {
      account-uos-storage-blob-data-contributor = {
        scope_id           = local.account_storage_id
        role_definition_id = local.role_def_ids.storage_blob_data_contributor
        principal_id       = local.account_principal_id
        principal_type     = "ServicePrincipal"
      }
    } : {},

    # Project MI — agent storage grants (FR-050 / FR-051 / FR-052)
    local.project_storage_enabled ? {
      project-agent-storage-blob-data-contributor = {
        scope_id           = local.agent_storage_id
        role_definition_id = local.role_def_ids.storage_blob_data_contributor
        principal_id       = local.project_principal_id
        principal_type     = "ServicePrincipal"
      }
      project-agent-storage-blob-data-owner = {
        scope_id           = local.agent_storage_id
        role_definition_id = local.role_def_ids.storage_blob_data_owner
        principal_id       = local.project_principal_id
        principal_type     = "ServicePrincipal"
      }
      project-agent-storage-file-priv-contributor = {
        scope_id           = local.agent_storage_id
        role_definition_id = local.role_def_ids.storage_file_priv_contributor
        principal_id       = local.project_principal_id
        principal_type     = "ServicePrincipal"
      }
    } : {},

    # Project MI — AI Search grants (FR-053 / FR-054)
    local.project_search_enabled ? {
      project-search-index-data-contributor = {
        scope_id           = local.search_id
        role_definition_id = local.role_def_ids.search_index_data_contributor
        principal_id       = local.project_principal_id
        principal_type     = "ServicePrincipal"
      }
      project-search-service-contributor = {
        scope_id           = local.search_id
        role_definition_id = local.role_def_ids.search_service_contributor
        principal_id       = local.project_principal_id
        principal_type     = "ServicePrincipal"
      }
    } : {},

    # Project MI — Cosmos DB control-plane grants (FR-055 / FR-056)
    local.project_cosmos_enabled ? {
      project-cosmos-operator = {
        scope_id           = local.cosmos_id
        role_definition_id = local.role_def_ids.cosmos_operator
        principal_id       = local.project_principal_id
        principal_type     = "ServicePrincipal"
      }
      project-cosmos-documentdb-account-contributor = {
        scope_id           = local.cosmos_id
        role_definition_id = local.role_def_ids.documentdb_account_contributor
        principal_id       = local.project_principal_id
        principal_type     = "ServicePrincipal"
      }
    } : {},
  )

  # ---- Cosmos DB data-plane SQL role-assignment fan-out (FR-057) -------------
  cosmos_sql_role_assignments = local.project_cosmos_enabled ? {
    project-cosmos-data-contributor = {
      cosmos_account_id      = local.cosmos_id
      sql_role_definition_id = local.cosmos_sql_data_contributor_role_id
      principal_id           = local.project_principal_id
    }
  } : {}
}
