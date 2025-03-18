variable "dns" {}
variable "log" {}
variable "vnet" {}
variable "firewall" {}
variable "remote_vnet" {}


variable "firewall_subnet_id" {
  description = "The ID of the subnet where the firewall is deployed."
  type        = string
}

variable "firewall_management_subnet_id" {
  description = "The ID of the management subnet where the firewall is deployed."
  type        = string
}


