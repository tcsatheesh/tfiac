###############################################################################
# Input contract
#
# A single typed object. Adds the FR-001 required `repo` field on top of the
# documented contract in input-schema.md (which still reflects the validation
# block set listed there).
###############################################################################

variable "input" {
  description = "Single batch request for the naming engine."

  type = object({
    topology    = string
    tenant      = string
    environment = string
    region      = string
    repo        = string

    services = list(object({
      type  = string
      count = optional(number, 1)

      subnets             = optional(list(object({ purpose = string })), [])
      nsg_rules           = optional(list(object({ purpose = string })), [])
      routes              = optional(list(object({ purpose = string })), [])
      private_endpoints   = optional(list(object({ subnet = string })), [])
      diagnostic_settings = optional(list(object({})), [])
    }))

    overrides = optional(any, {})
  })

  validation {
    condition     = contains(["hub", "spoke"], var.input.topology)
    error_message = "input.topology must be exactly \"hub\" or \"spoke\"."
  }

  validation {
    condition     = can(regex("^(hub|sp(0[1-9]|[1-9][0-9]))$", var.input.tenant))
    error_message = "input.tenant must be \"hub\" or a fixed-width spoke token sp01..sp99 (regex ^(hub|sp(0[1-9]|[1-9][0-9]))$)."
  }

  validation {
    condition = (
      (var.input.topology == "hub" && var.input.tenant == "hub") ||
      (var.input.topology == "spoke" && can(regex("^sp(0[1-9]|[1-9][0-9])$", var.input.tenant)))
    )
    error_message = "input.topology and input.tenant disagree: hub requires tenant=\"hub\"; spoke requires tenant=sp01..sp99."
  }

  validation {
    condition     = length(var.input.environment) > 0 && length(var.input.environment) <= 4
    error_message = "input.environment must be a non-empty short token (length 1..4)."
  }

  validation {
    condition     = length(var.input.repo) > 0
    error_message = "input.repo is required (FR-001 / FR-014); pass the consumer repository identifier verbatim."
  }
}
