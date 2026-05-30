# T006 - wrapper module inputs.
# Constitution II: intent only. `input` is the engine input bundle (matches
# modules/naming variable.input exactly). Observability knobs (`retention_in_days`,
# `daily_quota_gb`) are defence-in-depth duplicated here AND at the root stack
# (research D7).

variable "input" {
  description = "Engine input bundle (passed straight through to modules/naming). Tenant/environment/region/usecase/stack_purpose/repo intent."

  type = object({
    tenant        = string
    environment   = string
    region        = string
    usecase       = string
    stack_purpose = string
    repo          = string
  })

  # Defence-in-depth: mirror the engine's stack_purpose regex
  # (modules/naming/variables.tf, INV-* / catalogue rule) at the wrapper
  # boundary so tests/services_negative.tftest.hcl can attribute the
  # failure to var.input on this module instead of the deeper engine
  # module.
  validation {
    condition     = can(regex("^[a-z0-9]{3}$", var.input.stack_purpose))
    error_message = "input.stack_purpose must match ^[a-z0-9]{3}$ (e.g. \"log\", \"svc\", \"net\")."
  }
}

variable "workspace_key" {
  description = "Internal naming-engine map key for the workspace entry. NOT the Azure resource name. Default 'central' (the one-workspace-per-stack-instance shape; LOG-INV-11 / contracts/log-stack.md)."
  type        = string
  default     = "central"

  validation {
    condition     = can(regex("^[a-z0-9]{1,16}$", var.workspace_key))
    error_message = "workspace_key must match ^[a-z0-9]{1,16}$ (engine services[*].key regex); got \"${var.workspace_key}\"."
  }
}

variable "retention_in_days" {
  description = "Log Analytics workspace data retention in days. Integer in [30, 730] (LOG-INV-6, FR-105)."
  type        = number
  default     = 30

  validation {
    condition     = var.retention_in_days >= 30 && var.retention_in_days <= 730
    error_message = "retention_in_days must be an integer in [30, 730]; got ${var.retention_in_days}."
  }
}

variable "daily_quota_gb" {
  description = "Log Analytics workspace daily ingestion quota in GB. -1 (unlimited) or any positive integer (LOG-INV-7, FR-105)."
  type        = number
  default     = -1

  validation {
    condition     = var.daily_quota_gb == -1 || var.daily_quota_gb >= 1
    error_message = "daily_quota_gb must be -1 (unlimited) or a positive integer; got ${var.daily_quota_gb}."
  }
}
