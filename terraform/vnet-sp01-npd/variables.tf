variable "subscription_id" {
  type = string
  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id must be a lowercase GUID."
  }
}

variable "region" {
  type = string
  validation {
    condition     = contains(["swedencentral"], var.region)
    error_message = "region must be one of the platform-approved regions (day-one: swedencentral)."
  }
}

variable "repo" {
  type = string
  validation {
    condition     = length(var.repo) > 0
    error_message = "repo is required."
  }
}

variable "hub_remote_state_path" {
  type    = string
  default = "../vnet-hub-npd/terraform.tfstate"
}

variable "hub_vnet_id" {
  type    = string
  default = ""
}

variable "hub_firewall_private_ip" {
  type    = string
  default = ""
}

variable "hub_peered_spoke_vnet_names" {
  description = "Override for hub's peered_spoke_vnet_names output (test seam). Empty = read from hub remote state."
  type        = list(string)
  default     = []
}
