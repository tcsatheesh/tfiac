variable "subscription_id" {
  description = "Target Azure subscription id (hub-npd). GUID."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id must be a lowercase Azure subscription GUID."
  }
}

variable "repo" {
  description = "GitHub repo in <owner>/<name> form. Tagged onto every resource via the naming engine."
  type        = string
  default     = "tcsatheesh/tfiac"
}

variable "region" {
  description = "Azure CAF short-code region. Day-one MUST be \"swc\"."
  type        = string
  default     = "swc"

  validation {
    condition     = var.region == "swc"
    error_message = "region must be \"swc\" (BOOT-INV-1)."
  }
}

variable "tenant" {
  description = "Tenancy. Pinned to \"hub\" (the state SA is a hub-owned fixture; spoke envs use cross-sub remote state)."
  type        = string
  default     = "hub"

  validation {
    condition     = var.tenant == "hub"
    error_message = "tenant must be \"hub\" (BOOT-INV-2)."
  }
}

variable "environment" {
  description = "Environment short code. Day-one MUST be \"npd\"."
  type        = string
  default     = "npd"

  validation {
    condition     = contains(["npd", "prd"], var.environment)
    error_message = "environment must be npd or prd."
  }
}

variable "operator_object_id" {
  description = "Azure AD object id (GUID) of the human operator. When set, gets Storage Blob Data Owner on the state SA. Pass null in CI-only mode (FR-007)."
  type        = string
  default     = null

  validation {
    condition     = var.operator_object_id == null || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.operator_object_id))
    error_message = "operator_object_id must be a lowercase Azure AD object id GUID, or null."
  }
}

variable "gh_oidc_object_id" {
  description = "Azure AD object id (GUID) of the GitHub Actions OIDC service principal (the one with federated credential subject `repo:tcsatheesh/tfiac:environment:hub-npd`). Gets Storage Blob Data Contributor on the state SA (FR-007). Pass null to skip (e.g. first-apply before SP is created)."
  type        = string
  default     = null

  validation {
    condition     = var.gh_oidc_object_id == null || can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.gh_oidc_object_id))
    error_message = "gh_oidc_object_id must be a lowercase Azure AD object id GUID, or null."
  }
}

variable "legacy_state_backend" {
  description = "Legacy state SA descriptor used by data.terraform_remote_state.{dns,vnet,buildsvr} at bootstrap time. After bootstrap, every other stack uses variables/backend.hcl pointing at the NEW SA - this variable is only consumed during the one-shot bootstrap apply."
  type = object({
    resource_group_name  = string
    storage_account_name = string
    container_name       = string
    dns_key              = string
    vnet_key             = string
    buildsvr_key         = string
  })
  default = {
    resource_group_name  = "stcwe-rg-tfs-01"
    storage_account_name = "stcwetfstate01"
    container_name       = "tfstate"
    dns_key              = "hub/prd/dns.tfstate"
    vnet_key             = "hub/npd/vnet.tfstate"
    buildsvr_key         = "hub/npd/buildsvr.tfstate"
  }
}

variable "pe_subnet_role" {
  description = "Hub-vnet subnet role to attach the state SA Private Endpoint into. Default \"development\" per spec C-001 (already has Microsoft.Storage SE)."
  type        = string
  default     = "development"
}

# Test seam: when set, replaces the live remote_state reads with an
# inline shape. Lets tftest.hcl exercise the stack without a real
# legacy SA or network.
variable "remote_state_override" {
  description = "Test-only override for upstream remote state. When set, data.terraform_remote_state.{dns,vnet} are skipped and these values are used instead. MUST be null in production."
  type = object({
    pe_subnet_id     = string
    pe_subnet_vnetid = string
    blob_zone_id     = string
    blob_zone_name   = string
    dns_zone_rg      = string
  })
  default = null
}

variable "build_vm_override" {
  description = "Test-only override for the build VM principal id. When set, skips data.terraform_remote_state.buildsvr and uses the supplied id. MUST be null in production."
  type = object({
    principal_id = string
  })
  default = null
}
