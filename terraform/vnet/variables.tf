variable "subscription_id" {
  description = "Target Azure subscription id (GUID)."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id must be a lowercase Azure subscription GUID."
  }
}

variable "repo" {
  description = "GitHub repo in <owner>/<name> form. Tagged onto every resource via the naming engine."
  type        = string
}

variable "region" {
  description = "Azure CAF short-code region. MUST be \"swc\" day-one."
  type        = string

  validation {
    condition     = var.region == "swc"
    error_message = "region must be \"swc\" (VNET-INV-1)."
  }
}

variable "tenant" {
  description = "Tenancy identifier (hub|spXY)."
  type        = string

  validation {
    condition     = can(regex("^(hub|sp[0-9]{2})$", var.tenant))
    error_message = "tenant must match ^(hub|sp[0-9]{2})$."
  }
}

variable "environment" {
  description = "Environment short code (npd|prd)."
  type        = string

  validation {
    condition     = contains(["npd", "prd"], var.environment)
    error_message = "environment must be npd or prd (VNET-INV-2)."
  }
}

variable "role" {
  description = "Network role for this stack invocation (hub|spoke)."
  type        = string

  validation {
    condition     = contains(["hub", "spoke"], var.role)
    error_message = "role must be hub or spoke (VNET-INV-3)."
  }
}

variable "usecase" {
  description = "Stack usecase. Defaults to \"shd\" (shared)."
  type        = string
  default     = "shd"
}

variable "address_space" {
  description = "vnet address space (>=1 valid CIDR)."
  type        = list(string)

  validation {
    condition     = length(var.address_space) >= 1
    error_message = "address_space must contain at least one CIDR (VNET-INV-9)."
  }

  validation {
    condition     = alltrue([for c in var.address_space : can(cidrnetmask(c))])
    error_message = "Every address_space entry must be a valid CIDR (VNET-INV-9)."
  }
}

variable "subnets" {
  description = "Map of subnet role => CIDR. Roles must match modules/network/locals.tf role_catalogue."
  type        = map(string)

  validation {
    condition     = alltrue([for c in values(var.subnets) : can(cidrnetmask(c))])
    error_message = "Every subnets value must be a valid CIDR (VNET-INV-9)."
  }
}

variable "extra_nsg_rules" {
  description = "Reserved for future per-role NSG rule extensions. Map of role => list(rule object)."
  type        = map(any)
  default     = {}
}

variable "hub_state_backend" {
  description = "Remote-state backend descriptor for the hub vnet stack. REQUIRED when role=spoke; FORBIDDEN when role=hub. The subscription_id field, if set, scopes the azurerm.hub provider."
  type = object({
    resource_group_name  = string
    storage_account_name = string
    container_name       = string
    key                  = string
    subscription_id      = optional(string)
  })
  default = null

  # VNET-INV-6: spoke role REQUIRES hub_state_backend. Cross-variable
  # validation (Terraform >= 1.9). Fires before any data sources are read.
  validation {
    condition     = !(var.role == "spoke" && var.hub_state_backend == null)
    error_message = "VNET-INV-6: role=spoke requires var.hub_state_backend to be supplied."
  }

  # VNET-INV-7: hub role FORBIDS hub_state_backend.
  validation {
    condition     = !(var.role == "hub" && var.hub_state_backend != null)
    error_message = "VNET-INV-7: role=hub must NOT supply var.hub_state_backend."
  }
}

variable "firewall_sku_tier" {
  description = "Azure Firewall + Firewall Policy SKU tier for hub deployments (FR-209). One of Basic, Standard, Premium. Ignored when role=spoke."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.firewall_sku_tier)
    error_message = "firewall_sku_tier must be one of \"Basic\", \"Standard\", or \"Premium\" (FR-209)."
  }
}

variable "enable_hub_default_route" {
  description = "When role=hub, add 0.0.0.0/0 -> in-vnet firewall private IP to the shared hub route table (FR-210). Defaults to true so hub workload subnets (e.g. buildsvr) can reach the internet via the firewall. Ignored when role=spoke."
  type        = bool
  default     = true
}

variable "enable_hub_firewall" {
  description = "When role=hub, deploy the in-vnet Azure Firewall (+ policy + the two PIPs) (FR-227). Defaults to true for day-one parity. When false the firewall is torn down, the firewall outputs resolve null, the hub default route is suppressed, and no workload subnet attaches the shared route table (FR-228). Ignored when role=spoke."
  type        = bool
  default     = true
}

variable "enable_hub_nat_gateway" {
  description = "When role=hub, deploy a Standard NAT gateway (+ its zone-redundant Standard static PIP) and associate it with the hub workload subnets that need egress (development, pre-production, buildsvr) (FR-229). Defaults to false (nothing created) for day-one parity. Provides a firewall-independent egress path so the hub firewall can be torn down with zero egress gap. Ignored when role=spoke."
  type        = bool
  default     = false
}

variable "enable_spoke_nat_gateway" {
  description = "When role=spoke, deploy a Standard NAT gateway (+ its zone-redundant Standard static PIP) in the spoke's own VNet/RG and associate it with the spoke workload subnets that need egress (development, pre-production, function-app, logic-app, preprod-func, preprod-logic) (FR-230). Defaults to false (nothing created) for day-one parity. A NAT gateway is not transitive over peering, so a spoke needing internet egress must own one; flip to true + roll out and egress 'just works'. Ignored when role=hub."
  type        = bool
  default     = false
}

variable "hub_state_override" {
  description = "TEST-ONLY: synthesize hub remote-state outputs without contacting the backend. When non-null, the root stack skips data.terraform_remote_state.hub and uses these values directly. Production tfvars MUST leave this null."
  type = object({
    vnet_id             = string
    vnet_name           = string
    resource_group_name = string
    firewall_private_ip = optional(string)
  })
  default = null
}

variable "dns_state_backend" {
  description = "Remote-state backend descriptor for the DNS stack (terraform/dns/, state key hub/prd/dns.tfstate). REQUIRED for both hub and spoke roles per C16.1 — vnet-links to the private DNS catalogue apply to every consumer. The subscription_id field scopes the azurerm.dns provider (FR-214, FR-221, C16.4, C16.11)."
  type = object({
    subscription_id      = string
    resource_group_name  = string
    storage_account_name = string
    container_name       = string
    key                  = string
  })

  # Defence-in-depth (plan §4): catch obvious typos in the state-blob key.
  validation {
    condition     = endswith(var.dns_state_backend.key, ".tfstate")
    error_message = "dns_state_backend.key must end with \".tfstate\"."
  }

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.dns_state_backend.subscription_id))
    error_message = "dns_state_backend.subscription_id must be a lowercase Azure subscription GUID."
  }
}
