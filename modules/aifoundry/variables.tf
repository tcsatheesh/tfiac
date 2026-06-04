variable "canonical_name" {
  description = "Engine-emitted canonical Azure resource name."
  type        = string

  validation {
    condition     = length(var.canonical_name) > 0 && length(var.canonical_name) <= 260
    error_message = "canonical_name must be non-empty and <= 260 chars."
  }

  validation {
    condition     = can(regex("^[a-z0-9.-]+$", var.canonical_name))
    error_message = "canonical_name must match ^[a-z0-9.-]+$ (engine INV-7)."
  }
}

variable "resource_group_name" {
  description = "Services-stack RG name."
  type        = string

  validation {
    condition     = length(var.resource_group_name) > 0
    error_message = "resource_group_name must be non-empty."
  }
}

variable "location" {
  description = "Full Azure region name (e.g. uksouth)."
  type        = string

  validation {
    condition     = length(var.location) > 0
    error_message = "location must be non-empty."
  }
}

variable "tags" {
  description = "Engine-emitted tag map."
  type        = map(string)
}

variable "engine_record" {
  description = "Full engine record from module.naming.names[canonical_name]."
  type = object({
    service_type    = string
    service_purpose = optional(string)
    stack_purpose   = optional(string)
    parent          = optional(string)
    tags            = map(string)
    azure_max       = number
  })
}

variable "overrides" {
  description = "Per-instance attribute override map merged on top of local.defaults."
  type        = map(any)
  default     = {}
}

# ----- C-014 (Amendment 2026-05-31) — Shared hub Log Analytics wiring -----
variable "shared_log_analytics_workspace_id" {
  description = "Azure resource ID of the SHARED hub Log Analytics workspace (provisioned by terraform/log/) where this resource emits its diagnostic settings. See spec.md C-014."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/.+/providers/Microsoft\\.OperationalInsights/workspaces/.+$", var.shared_log_analytics_workspace_id))
    error_message = "shared_log_analytics_workspace_id must be a full Azure resource ID of the form /subscriptions/<sub>/.../providers/Microsoft.OperationalInsights/workspaces/<name> (spec.md C-014)."
  }
}

variable "diagnostic_settings_enabled" {
  description = "Operator escape hatch: set to false to skip the default azurerm_monitor_diagnostic_setting wiring to the shared hub LA. Default true preserves the C-014 contract. Document the opt-out reason in the PR body."
  type        = bool
  default     = true
}

# ----- C-018 (Amendment 2026-05-31) — Private endpoint wiring (FR-027) -----
variable "private_endpoint_enabled" {
  description = "C-018: when true, provision an azurerm_private_endpoint for the Cognitive Services account and default properties.publicNetworkAccess to \"Disabled\". Default false preserves the C-017 day-one behaviour (no PE, public access Enabled)."
  type        = bool
  default     = false
}

variable "private_endpoint_subnet_id" {
  description = "C-018: resource ID of the subnet the private-endpoint NIC lands in. Required (non-null) when private_endpoint_enabled = true; ignored otherwise."
  type        = string
  default     = null

  validation {
    condition     = var.private_endpoint_subnet_id == null || can(regex("^/subscriptions/.+/resourceGroups/.+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.private_endpoint_subnet_id))
    error_message = "private_endpoint_subnet_id must be null or a full subnet resource ID of the form /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet>/subnets/<subnet>."
  }
}

variable "private_dns_zone_ids" {
  description = "C-018: hub private DNS zone resource IDs the private endpoint registers A-records into (cogsvc/openai/aiservices). Required non-empty when private_endpoint_enabled = true."
  type        = list(string)
  default     = []
}

# ----- C-019 (Amendment 2026-06-01) — Application Insights tracing (FR-028) -----
variable "application_insights_enabled" {
  description = "C-019: when true, provision a workspace-based azurerm_application_insights anchored at the SHARED hub Log Analytics workspace (var.shared_log_analytics_workspace_id) and attach it to the Foundry account as a Microsoft.CognitiveServices/accounts/connections of category \"AppInsights\" so the Foundry Tracing feature funnels telemetry into the hub LA. Default false preserves the C-018 day-one behaviour (no App Insights, no connection)."
  type        = bool
  default     = false
}

# ----- C-051 (Amendment 2026-06-03) — telemetry public-access surface (FR-041 §2) -----
variable "telemetry_internet_access_enabled" {
  description = "C-051 / FR-041 §2: when false, set internet_ingestion_enabled = false and internet_query_enabled = false on the Foundry-tracing Application Insights component (the supported 'public access disabled' surface — App Insights has no classic private endpoint; full privacy is AMPLS, a tracked follow-up). Default true preserves day-one behaviour. The services stack drives this from var.private_by_default. Only meaningful when application_insights_enabled = true."
  type        = bool
  default     = true
}

# ----- C-022..C-026 / FR-031 (Amendment 2026-06-02) — Hosted-Agent network injection -----
variable "network_injection_enabled" {
  description = "FR-031 / C-022: when true, the Foundry account is created with Hosted-Agent network injection (properties.networkInjections scenario=agent bound to var.agent_subnet_id), three BYO account connections (Storage/Cosmos/Search), and an Agents capabilityHosts child. Injection is settable ONLY at account creation (VC-1) — flipping this on an existing account requires an operator-approved recreate. Default false preserves the post-FR-028 day-one behaviour (no networkInjections, no connections, no capability host)."
  type        = bool
  default     = false
}

variable "agent_subnet_id" {
  description = "FR-031 / C-023 / VC-5: full resource ID of the dedicated agent subnet (delegated to Microsoft.App/environments, recommended /24, exclusive to this account). Required (non-null) when network_injection_enabled = true; ignored otherwise. The subnet is created by the 004-vnet engine + an instance VNet, never by this module."
  type        = string
  default     = null

  validation {
    condition     = var.agent_subnet_id == null || can(regex("^/subscriptions/.+/resourceGroups/.+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.agent_subnet_id))
    error_message = "agent_subnet_id must be null or a full subnet resource ID of the form /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet>/subnets/<subnet>."
  }
}

variable "agent_storage_account_id" {
  description = "FR-031 / C-024 / VC-3/VC-4: full resource ID of the BYO Azure Storage account used for the capability host storageConnections leg. Required (non-null) when network_injection_enabled = true; ignored otherwise. Provisioned by a separate feature, never by this module."
  type        = string
  default     = null

  validation {
    condition     = var.agent_storage_account_id == null || can(regex("^/subscriptions/.+/resourceGroups/.+/providers/Microsoft\\.Storage/storageAccounts/[^/]+$", var.agent_storage_account_id))
    error_message = "agent_storage_account_id must be null or a full Microsoft.Storage/storageAccounts resource ID."
  }
}

variable "agent_cosmosdb_account_id" {
  description = "FR-031 / C-024 / VC-3/VC-4: full resource ID of the BYO Azure Cosmos DB account used for the capability host threadStorageConnections leg. Required (non-null) when network_injection_enabled = true; ignored otherwise. Provisioned by the dependent cosmosdb feature (CA-013 #2), never by this module."
  type        = string
  default     = null

  validation {
    condition     = var.agent_cosmosdb_account_id == null || can(regex("^/subscriptions/.+/resourceGroups/.+/providers/Microsoft\\.DocumentDB/databaseAccounts/[^/]+$", var.agent_cosmosdb_account_id))
    error_message = "agent_cosmosdb_account_id must be null or a full Microsoft.DocumentDB/databaseAccounts resource ID."
  }
}

variable "agent_search_service_id" {
  description = "FR-031 / C-024 / VC-3/VC-4: full resource ID of the BYO Azure AI Search service used for the capability host vectorStoreConnections leg. Required (non-null) when network_injection_enabled = true; ignored otherwise. Provisioned by a separate feature, never by this module."
  type        = string
  default     = null

  validation {
    condition     = var.agent_search_service_id == null || can(regex("^/subscriptions/.+/resourceGroups/.+/providers/Microsoft\\.Search/searchServices/[^/]+$", var.agent_search_service_id))
    error_message = "agent_search_service_id must be null or a full Microsoft.Search/searchServices resource ID."
  }
}

# ----- C-060 / FR-044 (Amendment 2026-06-04) — userOwnedStorage (account's own
# Storage) — template-exact-match -----
variable "account_storage_account_id" {
  description = "FR-044 / C-060: full resource ID of the account's own (userOwnedStorage) Azure Storage account. When non-null the module (i) adds a properties.userOwnedStorage = [{ resourceId }] entry to the account body and (ii) provisions an AzureStorageAccount account connection (fixed name \"accountstorage\") targeting the account's Blob endpoint. This is the SECOND storage in the portal Standard-Agent template (fndrystrg00002), distinct from the BYO agent thread/file store (agent_storage_account_id). Default null preserves day-one behaviour (no userOwnedStorage, no connection). Provisioned by the services stack as a second `storage` selection, never by this module."
  type        = string
  default     = null

  validation {
    condition     = var.account_storage_account_id == null || can(regex("^/subscriptions/.+/resourceGroups/.+/providers/Microsoft\\.Storage/storageAccounts/[^/]+$", var.account_storage_account_id))
    error_message = "account_storage_account_id must be null or a full Microsoft.Storage/storageAccounts resource ID."
  }
}

variable "account_storage_connection_enabled" {
  description = "FR-044 / C-060: known-at-plan toggle that gates the userOwnedStorage body property + the 'accountstorage' connection. Kept separate from account_storage_account_id (whose value is computed, hence unknown at plan) so count/for_each never depend on an unknown — mirrors network_injection_enabled. When true, account_storage_account_id MUST be non-null (enforced by the account precondition). Default false preserves day-one behaviour."
  type        = bool
  default     = false
}

# ----- C-061 / FR-045 (Amendment 2026-06-04) — Key Vault connection on the
# Foundry account — template-exact-match -----
variable "keyvault_account_id" {
  description = "FR-045 / C-061: full resource ID of the Key Vault to attach to the Foundry account as a Microsoft.CognitiveServices/accounts/connections of category \"AzureKeyVault\" (authType AccountManagedIdentity, fixed name \"keyvault\", isSharedToAll=true) so child projects inherit it. Mirrors the portal Standard-Agent template's `<account>-keyvault` connection. Default null preserves day-one behaviour (no Key Vault connection). The vault itself is provisioned by the services stack as a `keyvault` selection (private-by-default), never by this module."
  type        = string
  default     = null

  validation {
    condition     = var.keyvault_account_id == null || can(regex("^/subscriptions/.+/resourceGroups/.+/providers/Microsoft\\.KeyVault/vaults/[^/]+$", var.keyvault_account_id))
    error_message = "keyvault_account_id must be null or a full Microsoft.KeyVault/vaults resource ID."
  }
}

variable "keyvault_connection_enabled" {
  description = "FR-045 / C-061: known-at-plan toggle that gates the 'keyvault' AzureKeyVault connection. Kept separate from keyvault_account_id (whose value is computed, hence unknown at plan) so count never depends on an unknown — mirrors network_injection_enabled. When true, keyvault_account_id MUST be non-null (enforced by the account precondition). Default false preserves day-one behaviour."
  type        = bool
  default     = false
}
