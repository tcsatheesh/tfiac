variable "spoke_vnet_id" {
  description = "Resource id of the spoke (local) vnet."
  type        = string
}

variable "spoke_vnet_name" {
  description = "Name of the spoke vnet."
  type        = string
}

variable "spoke_resource_group_name" {
  description = "RG name that holds the spoke vnet."
  type        = string
}

variable "hub_vnet_id" {
  description = "Resource id of the hub (remote) vnet (lives in hub subscription)."
  type        = string
}

variable "hub_vnet_name" {
  description = "Name of the hub vnet."
  type        = string
}

variable "hub_resource_group_name" {
  description = "RG name that holds the hub vnet."
  type        = string
}
