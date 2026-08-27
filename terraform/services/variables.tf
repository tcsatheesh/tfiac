# Root-stack inputs (data-model § 1; CA-002).
# Exactly 8 required + 1 optional. Any other top-level variable is forbidden.

variable "subscription_id" {
  description = "Target Azure subscription id (GUID). Cross-checked at plan time via check.subscription_match in main.tf."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id must be a lowercase Azure subscription GUID."
  }

  validation {
    condition     = var.subscription_id != "REPLACE-WITH-RUNTIME-SUBSCRIPTION-ID"
    error_message = "subscription_id must be injected at runtime (CA-011): use `-var subscription_id=$AZURE_SUBSCRIPTION_ID` or the equivalent env var. The placeholder in variables/<tenant>/<env>/services.tfvars.json is intentional."
  }
}

variable "topology" {
  description = "Topology discriminator: hub|spoke. Cross-checked against tenant (CA-003)."
  type        = string

  validation {
    condition     = contains(["hub", "spoke"], var.topology)
    error_message = "topology must be \"hub\" or \"spoke\"."
  }
}

variable "tenant" {
  description = "Tenant short code: hub | sp01..sp99. Engine ALSO enforces ^(hub|sp[0-9]{2})$."
  type        = string

  validation {
    condition     = can(regex("^(hub|sp(0[1-9]|[1-9][0-9]))$", var.tenant))
    error_message = "tenant must match ^(hub|sp(0[1-9]|[1-9][0-9]))$ (e.g. \"hub\", \"sp01\")."
  }

  validation {
    condition = (
      (var.topology == "hub" && var.tenant == "hub") ||
      (var.topology == "spoke" && can(regex("^sp(0[1-9]|[1-9][0-9])$", var.tenant)))
    )
    error_message = "CA-003: topology/tenant cross-check failed. topology=hub ⟺ tenant=hub; topology=spoke ⟺ tenant=~/^sp[0-9]{2}$/."
  }
}

variable "environment" {
  description = "Environment short code: dev|pre|prd (workload environments only; 'npd' is reserved for shared/hub stacks per C-016 / FR-025)."
  type        = string

  validation {
    condition     = contains(["dev", "pre", "prd"], var.environment)
    error_message = "environment must be one of dev|pre|prd (C-016 / FR-025); 'npd' is reserved for shared/hub stacks."
  }
}

variable "region" {
  description = "Azure CAF short-code region (e.g. uks, swc). Engine catalogue (INV-10) re-validates."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,4}$", var.region))
    error_message = "region must match ^[a-z0-9]{3,4}$."
  }
}

variable "usecase" {
  description = "Stack usecase token (3–4 lowercase alphanumerics per C-016 / FR-025). Matches engine regex ^[a-z0-9]{3,4}$ so the CA-004 strategy-B fallback service_purpose = coalesce(s.purpose, var.usecase) always satisfies the engine's service_purpose validation."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,4}$", var.usecase))
    error_message = "usecase must be 3–4 lowercase alphanumerics (C-016 / FR-025)."
  }
}

variable "repo" {
  description = "Source repository slug for the managed_by trail (engine `repo` tag)."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$", var.repo)) && length(var.repo) <= 256
    error_message = "repo must match ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ and be <= 256 chars."
  }
}

variable "services" {
  description = "Operator selection of services to provision. See data-model § 2 for the per-entry schema."
  type = list(object({
    type                = string
    count               = optional(number, 1)
    purpose             = optional(string)
    overrides           = optional(map(any), {})
    private_endpoints   = optional(list(any), [])
    diagnostic_settings = optional(list(any), [])
  }))
  default = []

  validation {
    condition = alltrue([
      for s in var.services :
      contains([
        "keyvault", "storage", "log_analytics", "app_insights", "container_registry",
        "user_assigned_identity", "search", "openai",
        "language", "doc_intel", "function_app", "logic_app", "aml_workspace", "apim",
        "container_app_environment", "cosmosdb", "sql_server", "data_factory",
      ], s.type)
    ])
    error_message = "services[*].type must be one of the v1 selectable types (spec.md C-001 + C-015 + C-021 + FR-032 + FR-052). Other engine-catalogued types (vnet, nsg, vm, dns_zone, private_dns_zone, firewall, ...) are deferred or owned by other stacks; see terraform/services/locals.tf::deferred_reason."
  }

  validation {
    condition = alltrue([
      for s in var.services : s.count >= 0 && s.count <= 999
    ])
    error_message = "services[*].count must be in [0, 999] (engine INV-3 re-enforces ≤999)."
  }

  validation {
    condition = alltrue([
      for s in var.services :
      s.purpose == null || can(regex("^[a-z0-9]{3}$", s.purpose))
    ])
    error_message = "services[*].purpose (when set) must match ^[a-z0-9]{3}$ (engine service_purpose regex)."
  }

  validation {
    condition = alltrue([
      for s in var.services : length(s.private_endpoints) == 0
    ])
    error_message = "services[*].private_endpoints deferred to follow-up; see spec.md A4."
  }

  validation {
    condition = alltrue([
      for s in var.services : length(s.diagnostic_settings) == 0
    ])
    error_message = "services[*].diagnostic_settings deferred to follow-up; see spec.md A4."
  }
}

variable "overrides" {
  description = "Map keyed by engine-emitted canonical name -> per-instance attribute override map. Unmatched keys hard-fail via check.overrides_keys_resolved (CA-006)."
  type        = map(map(any))
  default     = {}
}

# ----- C-014 (Amendment 2026-05-31) — Shared hub LA backend coordinates -----
# Default values match the bootstrap state SA so the day-one operator
# experience is zero-config. Each carries a regex validation pinned to
# the bootstrap naming convention.

variable "tfstate_resource_group" {
  description = "Resource group hosting the hub state SA used to read the shared LA backend (terraform/log/). Default matches terraform/bootstrap/. See spec.md C-014."
  type        = string
  default     = "rg-tfs-shd-hub-npd-swc-001"

  validation {
    condition     = can(regex("^rg-[a-z0-9-]{1,80}$", var.tfstate_resource_group))
    error_message = "tfstate_resource_group must match ^rg-[a-z0-9-]{1,80}$ (bootstrap RG naming convention)."
  }
}

variable "tfstate_storage_account" {
  description = "Storage account hosting the hub state container. Default matches terraform/bootstrap/. See spec.md C-014."
  type        = string
  default     = "sttfsshdhubnpdswc001"

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.tfstate_storage_account))
    error_message = "tfstate_storage_account must match ^[a-z0-9]{3,24}$ (Azure storage account naming rules)."
  }
}

variable "tfstate_container" {
  description = "Blob container in the state SA holding tfstate blobs. Default matches terraform/bootstrap/. See spec.md C-014."
  type        = string
  default     = "tfstate"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{2,62}$", var.tfstate_container))
    error_message = "tfstate_container must match ^[a-z0-9][a-z0-9-]{2,62}$ (Azure container naming rules)."
  }
}

# ----- C-048 (Amendment 2026-06-03) — private-by-default master switch (FR-041) -----
variable "private_by_default" {
  description = "FR-041 / C-048: master switch. When true (the default), every Private-Link-capable selectable service is deployed with public network access disabled and a private endpoint enabled UNLESS its own per-service toggle is explicitly set. Each per-service toggle (enable_*_private_endpoint) is resolved as coalesce(<explicit>, var.private_by_default): an explicit true/false always wins; null (the new default) inherits this master. Set false to reproduce pre-FR-041 (public, opt-in) behaviour byte-for-byte (C-052). Requires both remote-state backends when any PE-capable service is selected (C-049)."
  type        = bool
  default     = true
}

variable "private_endpoint_subnet_role" {
  description = "C-018: spoke VNet subnet role (from the network-stack role catalogue) the private-endpoint NIC lands in. Looked up via the vnet remote state. Only consulted when a private endpoint is enabled."
  type        = string
  default     = "development"

  validation {
    condition = contains([
      "development", "pre-production", "api-management", "buildsvr",
      "function-app", "logic-app", "preprod-func", "preprod-logic",
      "container-apps", "agents", "bastion", "firewall", "firewall-mgmt",
    ], var.private_endpoint_subnet_role)
    error_message = "private_endpoint_subnet_role must be one of the 13 known network-stack subnet roles (C-032 adds 'agents')."
  }
}

variable "vnet_state_backend" {
  description = "C-018: remote-state backend coordinates for the spoke VNet stack (terraform/vnet/) whose subnets host the private endpoints. Required (non-null) when any private endpoint or Container Apps environment is enabled."
  type = object({
    resource_group_name  = string
    storage_account_name = string
    container_name       = string
    key                  = string
  })
  default = null

  # C-021 (FR-030): the internal Container Apps environment needs the spoke VNet
  # remote state (delegated subnet + vnet id for the DNS link).
  validation {
    condition     = !var.enable_container_apps || var.vnet_state_backend != null
    error_message = "enable_container_apps = true requires vnet_state_backend to be set."
  }
}

variable "dns_state_backend" {
  description = "C-018: remote-state backend coordinates for the hub private-DNS stack (terraform/dns/) supplying the private-link DNS zone IDs. Required (non-null) when any private endpoint is enabled."
  type = object({
    resource_group_name  = string
    storage_account_name = string
    container_name       = string
    key                  = string
  })
  default = null

  # C-020 (FR-029): the ACR private endpoint needs both the spoke VNet (subnet)
  # and the hub DNS (acr zone) remote states.
  validation {
    condition     = !(coalesce(var.enable_container_registry_private_endpoint, var.private_by_default) && length([for s in var.services : s if s.type == "container_registry"]) > 0) || (var.vnet_state_backend != null && var.dns_state_backend != null)
    error_message = "a private container registry endpoint (enable_container_registry_private_endpoint = true, or inherited from private_by_default = true) with a 'container_registry' selected requires both vnet_state_backend and dns_state_backend to be set."
  }

  # FR-032: Cosmos DB is private-only — selecting it requires both the spoke
  # VNet (PE subnet) and hub DNS (cosmos-sql zone) remote states.
  validation {
    condition     = length([for s in var.services : s if s.type == "cosmosdb"]) == 0 || (var.vnet_state_backend != null && var.dns_state_backend != null)
    error_message = "selecting a 'cosmosdb' service requires both vnet_state_backend and dns_state_backend to be set (FR-032 — Cosmos DB is private-only)."
  }

  # C-035 (FR-034): the storage private endpoint needs both the spoke VNet
  # (subnet) and the hub DNS (blob zone) remote states.
  validation {
    condition     = !(coalesce(var.enable_storage_private_endpoint, var.private_by_default) && length([for s in var.services : s if s.type == "storage"]) > 0) || (var.vnet_state_backend != null && var.dns_state_backend != null)
    error_message = "a private storage endpoint (enable_storage_private_endpoint = true, or inherited from private_by_default = true) with a 'storage' selected requires both vnet_state_backend and dns_state_backend to be set."
  }

  # C-039 (FR-035): the search private endpoint needs both the spoke VNet
  # (subnet) and the hub DNS (search zone) remote states.
  validation {
    condition     = !(coalesce(var.enable_search_private_endpoint, var.private_by_default) && length([for s in var.services : s if s.type == "search"]) > 0) || (var.vnet_state_backend != null && var.dns_state_backend != null)
    error_message = "a private search endpoint (enable_search_private_endpoint = true, or inherited from private_by_default = true) with a 'search' selected requires both vnet_state_backend and dns_state_backend to be set."
  }

  # C-050 (FR-041): the Key Vault private endpoint needs both the spoke VNet
  # (subnet) and the hub DNS (vault zone) remote states.
  validation {
    condition     = !(coalesce(var.enable_keyvault_private_endpoint, var.private_by_default) && length([for s in var.services : s if s.type == "keyvault"]) > 0) || (var.vnet_state_backend != null && var.dns_state_backend != null)
    error_message = "a private Key Vault endpoint (enable_keyvault_private_endpoint = true, or inherited from private_by_default = true) with a 'keyvault' selected requires both vnet_state_backend and dns_state_backend to be set."
  }
}

# ----- C-020 (Amendment 2026-06-01) — Container registry private endpoint (FR-029) -----
variable "enable_container_registry_private_endpoint" {
  description = "C-020 / FR-041: when true, every selected container_registry is deployed as Premium with public_network_access disabled and an Azure private endpoint (+ hub privatelink.azurecr.io DNS) so it is reachable only from the spoke VNet. Reuses vnet_state_backend + dns_state_backend (the acr zone) and private_endpoint_subnet_role. Only meaningful when a 'container_registry' is selected (enforced by check.acr_pe_requires_registry). null (default) inherits var.private_by_default; explicit false forces day-one (Standard, public) behaviour."
  type        = bool
  default     = null
}

# ----- C-050 (Amendment 2026-06-03) — Key Vault private endpoint (FR-041) -----
variable "enable_keyvault_private_endpoint" {
  description = "C-050 / FR-041: when true, every selected key vault is deployed with public network access disabled (network_acls default_action = Deny, bypass = AzureServices) and an Azure private endpoint (subresource 'vault', + hub privatelink.vaultcore.azure.net DNS) so it is reachable only from the spoke VNet. Reuses vnet_state_backend + dns_state_backend (the vault zone) and private_endpoint_subnet_role. Only meaningful when a 'keyvault' is selected (enforced by check.keyvault_pe_requires_keyvault). null (default) inherits var.private_by_default; explicit false forces public behaviour."
  type        = bool
  default     = null
}

# ----- C-035 (Amendment 2026-06-02) — Storage account private endpoint (FR-034) -----
variable "enable_storage_private_endpoint" {
  description = "C-035 / FR-041: when true, every selected storage account is deployed with public_network_access disabled and an Azure private endpoint (subresource 'blob', + hub privatelink.blob.core.windows.net DNS) so it is reachable only from the spoke VNet. Reuses vnet_state_backend + dns_state_backend (the blob zone) and private_endpoint_subnet_role. Only meaningful when a 'storage' is selected (enforced by check.storage_pe_requires_storage). null (default) inherits var.private_by_default; explicit false forces day-one (public) behaviour."
  type        = bool
  default     = null
}

# ----- C-039 (Amendment 2026-06-02) — AI Search private endpoint (FR-035) -----
variable "enable_search_private_endpoint" {
  description = "C-039 / FR-041: when true, every selected search service is deployed with public_network_access disabled and an Azure private endpoint (subresource 'searchService', + hub privatelink.search.windows.net DNS) so it is reachable only from the spoke VNet. Reuses vnet_state_backend + dns_state_backend (the search zone) and private_endpoint_subnet_role. Only meaningful when a 'search' is selected (enforced by check.search_pe_requires_search). null (default) inherits var.private_by_default; explicit false forces day-one (public) behaviour."
  type        = bool
  default     = null
}

# ----- C-021 (Amendment 2026-06-01) — Container Apps internal environment (FR-030) -----
variable "enable_container_apps" {
  description = "C-021: when true, every selected container_app_environment is deployed as an INTERNAL (private, VNet-injected) Managed Environment with a private default-domain DNS zone linked to the spoke VNet. Supplies the delegated subnet + vnet id from vnet_state_backend. Only meaningful when a 'container_app_environment' is selected (enforced by check.container_app_env_requires_subnet). Default false preserves prior behaviour (type unselectable end-to-end)."
  type        = bool
  default     = false
}

variable "container_apps_subnet_role" {
  description = "C-021: spoke VNet subnet role (delegated to Microsoft.App/environments) the internal Container Apps environment is injected into. Looked up via the vnet remote state. Only consulted when enable_container_apps = true."
  type        = string
  default     = "container-apps"

  validation {
    condition = contains([
      "development", "pre-production", "api-management", "buildsvr",
      "function-app", "logic-app", "preprod-func", "preprod-logic",
      "container-apps", "agents", "bastion", "firewall", "firewall-mgmt",
    ], var.container_apps_subnet_role)
    error_message = "container_apps_subnet_role must be one of the 13 known network-stack subnet roles (C-032 adds 'agents')."
  }
}

# FR-052 — Azure SQL Entra administrator. Entra-only auth (no SQL login). Null
# => the deploying client (data.azurerm_client_config). Set to the deploy
# runner's managed identity object id so the in-deployment ADF->SQL grant can
# authenticate as the server administrator (the grant runs on the runner via
# ActiveDirectoryManagedIdentity).
variable "sql_entra_admin_object_id" {
  description = "Object id of the Entra principal set as the Azure SQL server administrator. Null => the deploying client principal."
  type        = string
  default     = null

  validation {
    condition     = var.sql_entra_admin_object_id == null || can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", coalesce(var.sql_entra_admin_object_id, "00000000-0000-0000-0000-000000000000")))
    error_message = "sql_entra_admin_object_id must be null or a GUID."
  }
}

variable "sql_entra_admin_login" {
  description = "Display name/login for the Azure SQL Entra administrator."
  type        = string
  default     = "sql-entra-admin"
}
