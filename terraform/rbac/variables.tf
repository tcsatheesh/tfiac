variable "subscription_id" {
  description = "Target subscription id (provider + role-definition id scope)."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "services_state_backend" {
  description = <<-EOT
    azurerm remote-state backend of the consumed 006-services stack. This engine
    resolves the Foundry account/project and every BYO target id from that
    stack's outputs (naming, resource_ids, resource_group_id).
  EOT
  type = object({
    resource_group_name  = string
    storage_account_name = string
    container_name       = string
    key                  = string
  })
}

variable "enable_aifoundry_user_owned_storage" {
  description = <<-EOT
    Mirror of the services-stack toggle (FR-044). Gates the ACCOUNT managed
    identity Storage Blob Data Contributor grant on the user-owned storage
    (FR-049). When true the stack requires two storages with distinct purposes.
  EOT
  type        = bool
  default     = false
}

variable "enable_aifoundry_keyvault_connection" {
  description = <<-EOT
    Mirror of the services-stack toggle (FR-045). Gates the ACCOUNT managed
    identity Key Vault Crypto grants on the Key Vault (FR-046/FR-047).
  EOT
  type        = bool
  default     = false
}

variable "agent_storage_purpose" {
  description = <<-EOT
    service_purpose (3 chars [a-z0-9]) identifying the AGENT storage account
    (the project managed identity's BYO blob/file store). Must match the value
    the services stack used. Required whenever two storages are present.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.agent_storage_purpose == null || can(regex("^[a-z0-9]{3}$", var.agent_storage_purpose))
    error_message = "agent_storage_purpose must be exactly three [a-z0-9] characters."
  }
}

variable "account_storage_purpose" {
  description = <<-EOT
    service_purpose (3 chars [a-z0-9]) identifying the ACCOUNT/user-owned storage
    account (the account managed identity's userOwnedStorage). Must differ from
    agent_storage_purpose. Required whenever enable_aifoundry_user_owned_storage.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.account_storage_purpose == null || can(regex("^[a-z0-9]{3}$", var.account_storage_purpose))
    error_message = "account_storage_purpose must be exactly three [a-z0-9] characters."
  }

  validation {
    condition     = var.account_storage_purpose == null || var.agent_storage_purpose == null || var.account_storage_purpose != var.agent_storage_purpose
    error_message = "account_storage_purpose must differ from agent_storage_purpose so the two storages are distinguishable."
  }
}
