# Variables for modules/naming - public contract.
# See specs/001-naming-convention-engine/contracts/naming-engine.md
# and specs/001-naming-convention-engine/data-model.md for the
# authoritative definitions of every shape and constraint here.

variable "input" {
  description = "Stack-level intent bundle. All fields lowercase except repo (case-preserving)."

  type = object({
    tenant        = string
    environment   = string
    region        = string
    usecase       = string
    stack_purpose = string
    repo          = string
  })

  validation {
    condition     = can(regex("^(hub|sp[0-9]{2})$", var.input.tenant))
    error_message = "input.tenant must match ^(hub|sp[0-9]{2})$ (e.g. \"hub\", \"sp01\")."
  }

  validation {
    condition     = can(regex("^[a-z]{3}$", var.input.environment))
    error_message = "input.environment must match ^[a-z]{3}$ (e.g. \"npd\", \"dev\", \"pre\", \"prd\")."
  }

  validation {
    condition     = can(regex("^[a-z0-9]{3,4}$", var.input.region))
    error_message = "input.region must match ^[a-z0-9]{3,4}$ (CAF short code; e.g. \"uks\", \"weu\", \"eus2\")."
  }

  validation {
    condition     = can(regex("^[a-z0-9]{3,4}$", var.input.usecase))
    error_message = "input.usecase must match ^[a-z0-9]{3,4}$ (e.g. \"shd\", \"uc01\")."
  }

  validation {
    condition     = can(regex("^[a-z0-9]{3}$", var.input.stack_purpose))
    error_message = "input.stack_purpose must match ^[a-z0-9]{3}$ (e.g. \"dns\", \"net\", \"svc\")."
  }

  validation {
    condition = (
      can(regex("^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$", var.input.repo))
      && length(var.input.repo) <= 256
    )
    error_message = "input.repo must match ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ and be <=256 chars (case preserved; sole exception to lowercase-only)."
  }
}

variable "services" {
  description = "Top-level service entries. Engine assigns instance numbers per (service_type, service_purpose, key)."

  type = list(object({
    service_type    = string
    service_purpose = optional(string)
    stack_purpose   = optional(string)
    key             = string
    fqdn            = optional(string)
    extra_tags      = optional(map(string), {})
  }))

  default = []

  validation {
    condition = alltrue([
      for s in var.services : can(regex("^[a-z0-9]{1,16}$", s.key))
    ])
    error_message = "Every services[*].key must match ^[a-z0-9]{1,16}$."
  }

  validation {
    condition = alltrue([
      for s in var.services :
      s.service_purpose == null || can(regex("^[a-z0-9]{3}$", s.service_purpose))
    ])
    error_message = "Every services[*].service_purpose (when set) must match ^[a-z0-9]{3}$."
  }

  validation {
    condition = alltrue([
      for s in var.services :
      s.stack_purpose == null || can(regex("^[a-z0-9]{3}$", s.stack_purpose))
    ])
    error_message = "Every services[*].stack_purpose (when set) must match ^[a-z0-9]{3}$."
  }

  validation {
    condition = alltrue([
      for s in var.services :
      s.fqdn == null || can(regex("^[a-z0-9.-]{1,253}$", s.fqdn))
    ])
    error_message = "Every services[*].fqdn (when set) must match ^[a-z0-9.-]{1,253}$ (lowercase DNS chars, <=253)."
  }

  validation {
    condition = alltrue([
      for s in var.services :
      (
        contains(["dns_zone", "private_dns_zone"], s.service_type)
        ? s.fqdn != null
        : s.fqdn == null
      )
    ])
    error_message = "services[*].fqdn is REQUIRED when service_type is dns_zone or private_dns_zone, and FORBIDDEN otherwise."
  }

  validation {
    condition = alltrue([
      for s in var.services :
      alltrue([
        for k, v in s.extra_tags :
        length(k) <= 512 && length(v) <= 256
      ])
    ])
    error_message = "Every services[*].extra_tags entry must have key <=512 chars and value <=256 chars (Azure tag limits)."
  }
}

variable "children" {
  description = "Child resources attached to top-level entries (subnets, NSG rules, private endpoints, etc)."

  type = list(object({
    service_type  = string
    parent_key    = string
    child_purpose = optional(string)
    key           = string
    extra_tags    = optional(map(string), {})
  }))

  default = []

  validation {
    condition = alltrue([
      for c in var.children : can(regex("^[a-z0-9]{1,16}$", c.key))
    ])
    error_message = "Every children[*].key must match ^[a-z0-9]{1,16}$."
  }

  validation {
    condition = alltrue([
      for c in var.children : can(regex("^[a-z0-9]{1,16}$", c.parent_key))
    ])
    error_message = "Every children[*].parent_key must match ^[a-z0-9]{1,16}$ (it references a top-level entry's key)."
  }

  validation {
    condition = alltrue([
      for c in var.children :
      c.child_purpose == null || can(regex("^[a-z0-9]{3,7}$", c.child_purpose))
    ])
    error_message = "Every children[*].child_purpose (when set) must match ^[a-z0-9]{3,7}$."
  }

  validation {
    condition = alltrue([
      for c in var.children :
      alltrue([
        for k, v in c.extra_tags :
        length(k) <= 512 && length(v) <= 256
      ])
    ])
    error_message = "Every children[*].extra_tags entry must have key <=512 chars and value <=256 chars (Azure tag limits)."
  }
}

variable "extra_tags" {
  description = "Stack-level additive tag map. Merged onto every emitted resource's tags. Baseline-key collisions fail loudly."

  type    = map(string)
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.extra_tags :
      length(k) <= 512 && length(v) <= 256
    ])
    error_message = "Every extra_tags entry must have key <=512 chars and value <=256 chars (Azure tag limits)."
  }
}
