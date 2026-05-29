variable "name" {
  description = "Engine-emitted firewall canonical name."
  type        = string
}

variable "location" {
  description = "Long-form Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name."
  type        = string
}

variable "data_subnet_id" {
  description = "AzureFirewallSubnet resource id."
  type        = string
}

variable "mgmt_subnet_id" {
  description = "AzureFirewallManagementSubnet resource id."
  type        = string
}

variable "data_pip_name" {
  description = "Engine-emitted PIP canonical name (data plane)."
  type        = string
}

variable "mgmt_pip_name" {
  description = "Engine-emitted PIP canonical name (management plane)."
  type        = string
}

variable "tags" {
  description = "Engine-emitted tags for the firewall."
  type        = map(string)
  default     = {}
}

variable "pip_data_tags" {
  description = "Engine-emitted tags for the data PIP."
  type        = map(string)
  default     = {}
}

variable "pip_mgmt_tags" {
  description = "Engine-emitted tags for the management PIP."
  type        = map(string)
  default     = {}
}
