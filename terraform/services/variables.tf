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
        "user_assigned_identity", "search", "openai", "aifoundry", "aifoundry_project",
        "language", "doc_intel", "function_app", "logic_app", "aml_workspace", "apim",
      ], s.type)
    ])
    error_message = "services[*].type must be one of the 16 v1 selectable types (spec.md C-001 + C-015). Other engine-catalogued types (vnet, nsg, vm, dns_zone, private_dns_zone, firewall, ...) are deferred or owned by other stacks; see terraform/services/locals.tf::deferred_reason."
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
