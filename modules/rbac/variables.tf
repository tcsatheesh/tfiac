variable "dns" {}
variable "log" {}
variable "vnet" {}
variable "services" {}

variable "container_registry_id" {
  description = "Container Registry ID"
  type        = string
}

variable "function_app_id" {
  description = "Azure Function App ID"
  type        = string
}

variable "function_app_managed_identity_id" {
  description = "Function App Managed Identity ID"
  type        = string
}