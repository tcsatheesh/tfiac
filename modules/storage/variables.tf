variable "storage_account_name" {
  type = string
}
variable "dns" {}
variable "log" {}
variable "vnet" {}
variable "services" {}

variable "public_network_access_enabled" {
  type    = bool
  default = false
}

variable "shared_access_key_enabled" {
  type    = bool
  default = false
}

variable "network_rules" {
  type = object({
    default_action = string
  })
  default = null
}
