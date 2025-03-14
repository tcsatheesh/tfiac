variable "dns" {}
variable "log" {}
variable "vnet" {}
variable "services" {}

variable "app_insights_id" {
  description = "The resource id of the application insights"
  type        = string
}
variable "keyvault_id" {
  description = "The resource id of the key vault"
  type        = string
}
variable "container_registry_id" {
  description = "The resource id of the container registry"
  type        = string
}
variable "ai_services_id" {
  description = "The resource id of the AI Services"
  type        = string
}