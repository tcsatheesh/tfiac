variable "name" {
  description = "Engine-emitted bastion canonical name."
  type        = string
}

variable "location" {
  description = "Long-form Azure region."
  type        = string
}

variable "resource_group_id" {
  description = "RG resource id (used as parent_id for the bastion AVM)."
  type        = string
}

variable "subnet_id" {
  description = "AzureBastionSubnet resource id."
  type        = string
}

variable "public_ip_name" {
  description = "Engine-emitted PIP canonical name (bastion data plane)."
  type        = string
}

variable "tags" {
  description = "Engine-emitted tags for the bastion."
  type        = map(string)
  default     = {}
}

variable "public_ip_tags" {
  description = "Engine-emitted tags for the bastion data-plane PIP (FR-224)."
  type        = map(string)
  default     = {}
}
