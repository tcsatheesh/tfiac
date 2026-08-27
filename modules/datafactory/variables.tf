variable "canonical_name" {
  description = "Engine-emitted canonical Azure Data Factory name."
  type        = string

  validation {
    condition     = length(var.canonical_name) >= 3 && length(var.canonical_name) <= 63
    error_message = "canonical_name must be 3..63 chars (Azure Data Factory name limit)."
  }

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-]{1,61}[A-Za-z0-9]$", var.canonical_name))
    error_message = "canonical_name must match ^[A-Za-z0-9][A-Za-z0-9-]{1,61}[A-Za-z0-9]$ (ADF naming: alnum + hyphen, no leading/trailing hyphen)."
  }
}

variable "resource_group_name" {
  description = "Services-stack RG name."
  type        = string
}

variable "location" {
  description = "Full Azure region name (e.g. swedencentral)."
  type        = string
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
  description = "Per-instance attribute override map."
  type        = map(any)
  default     = {}
}

variable "shared_log_analytics_workspace_id" {
  description = "Azure resource ID of the SHARED hub Log Analytics workspace where the factory emits diagnostic settings."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/.+/providers/Microsoft\\.OperationalInsights/workspaces/.+$", var.shared_log_analytics_workspace_id))
    error_message = "shared_log_analytics_workspace_id must be a full Operational Insights workspace resource ID."
  }
}

variable "diagnostic_settings_enabled" {
  description = "Escape hatch: set false to skip diagnostic-setting wiring to the shared hub LA."
  type        = bool
  default     = true
}

# ----- Inbound private endpoints (private-by-default) -----
variable "private_endpoint_subnet_id" {
  description = "Resource ID of the subnet the ADF inbound private-endpoint NICs land in. Required (non-null)."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/.+/resourceGroups/.+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.private_endpoint_subnet_id))
    error_message = "private_endpoint_subnet_id must be a full subnet resource ID."
  }
}

variable "datafactory_private_dns_zone_ids" {
  description = "Hub private DNS zone IDs for the ADF `dataFactory` sub-resource (privatelink.datafactory.azure.net). Required non-empty."
  type        = list(string)

  validation {
    condition     = length(var.datafactory_private_dns_zone_ids) > 0
    error_message = "datafactory_private_dns_zone_ids must be non-empty (ADF is private-only)."
  }
}

variable "portal_private_dns_zone_ids" {
  description = "Hub private DNS zone IDs for the ADF `portal` sub-resource (privatelink.adf.azure.net). Required non-empty."
  type        = list(string)

  validation {
    condition     = length(var.portal_private_dns_zone_ids) > 0
    error_message = "portal_private_dns_zone_ids must be non-empty (ADF Studio private access)."
  }
}

# ----- Linked-service targets (managed private endpoints + MI auth) -----
# Each is optional: the corresponding managed PE + linked service + role
# assignment is created only when the target is present in the same stack.
variable "key_vault_id" {
  description = "Resource ID of the Key Vault ADF links to (null = no KV linked service)."
  type        = string
  default     = null
}

variable "link_key_vault" {
  description = "Plan-known flag: create the Key Vault managed PE + linked service + RBAC. Set from the stack's keyvault selection (the id/name are computed and cannot gate count)."
  type        = bool
  default     = false
}

variable "key_vault_name" {
  description = "Key Vault name (used to derive the managed-PE FQDN <name>.vault.azure.net)."
  type        = string
  default     = null
}

variable "storage_account_id" {
  description = "Resource ID of the Storage account ADF links to (null = no storage linked service)."
  type        = string
  default     = null
}

variable "link_storage" {
  description = "Plan-known flag: create the Storage managed PE + linked service + RBAC."
  type        = bool
  default     = false
}

variable "storage_account_name" {
  description = "Storage account name (used to derive the blob endpoint + managed-PE FQDN)."
  type        = string
  default     = null
}

variable "sql_server_id" {
  description = "Resource ID of the SQL logical server ADF links to (null = no SQL linked service)."
  type        = string
  default     = null
}

variable "link_sql" {
  description = "Plan-known flag: create the SQL managed PE + linked service + the data-plane grant."
  type        = bool
  default     = false
}

variable "sql_server_fqdn" {
  description = "SQL server FQDN (<name>.database.windows.net) for the managed PE + linked service + grant."
  type        = string
  default     = null
}

variable "sql_database_name" {
  description = "SQL database name the linked service targets."
  type        = string
  default     = null
}

variable "sql_grant_enabled" {
  description = "When true (and a SQL target is present), run the least-privilege T-SQL grant that creates the ADF managed-identity as a contained DB user (db_datareader/db_datawriter/db_ddladmin). Executes from the deploy runner (in-VNet) via sqlcmd + Entra auth as the SQL admin. Set false to skip and grant manually."
  type        = bool
  default     = true
}

# ----- Managed VNet IR compute-scale TTLs -----
# Not exposed by the azurerm IR resource; applied via an azapi patch.
variable "managed_ir_copy_compute_ttl_min" {
  description = "Managed VNet IR copyComputeScaleProperties.timeToLive, in minutes. Keeps copy compute warm to avoid per-activity cold-start queueing."
  type        = number
  default     = 20

  validation {
    condition     = var.managed_ir_copy_compute_ttl_min >= 5 && var.managed_ir_copy_compute_ttl_min <= 1440
    error_message = "managed_ir_copy_compute_ttl_min must be between 5 and 1440 minutes."
  }
}

variable "managed_ir_pipeline_external_compute_ttl_min" {
  description = "Managed VNet IR pipelineExternalComputeScaleProperties.timeToLive, in minutes. Keeps pipeline/external activity compute warm."
  type        = number
  default     = 20

  validation {
    condition     = var.managed_ir_pipeline_external_compute_ttl_min >= 5 && var.managed_ir_pipeline_external_compute_ttl_min <= 1440
    error_message = "managed_ir_pipeline_external_compute_ttl_min must be between 5 and 1440 minutes."
  }
}

# Azure rejects a copy-compute-scale block without a DIU value.
variable "managed_ir_copy_compute_diu" {
  description = "Managed VNet IR copyComputeScaleProperties.dataIntegrationUnit. Must be a multiple of 4 between 4 and 256."
  type        = number
  default     = 4

  validation {
    condition     = var.managed_ir_copy_compute_diu >= 4 && var.managed_ir_copy_compute_diu <= 256 && var.managed_ir_copy_compute_diu % 4 == 0
    error_message = "managed_ir_copy_compute_diu must be a multiple of 4 between 4 and 256."
  }
}

variable "managed_ir_pipeline_nodes" {
  description = "Managed VNet IR pipelineExternalComputeScaleProperties.numberOfPipelineNodes."
  type        = number
  default     = 1

  validation {
    condition     = var.managed_ir_pipeline_nodes >= 1 && var.managed_ir_pipeline_nodes <= 10
    error_message = "managed_ir_pipeline_nodes must be between 1 and 10."
  }
}

variable "managed_ir_external_nodes" {
  description = "Managed VNet IR pipelineExternalComputeScaleProperties.numberOfExternalNodes."
  type        = number
  default     = 1

  validation {
    condition     = var.managed_ir_external_nodes >= 1 && var.managed_ir_external_nodes <= 10
    error_message = "managed_ir_external_nodes must be between 1 and 10."
  }
}
