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
