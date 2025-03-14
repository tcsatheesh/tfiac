variable "dns" {}
variable "log" {}
variable "vnet" {}
variable "services" {}
variable "app_insights_instrumentation_key" {
  description = "The instrumentation key of the application insights"
  type        = string
}
variable "app_insights_connection_string" {
  description = "The connection string of the application insights"
  type        = string
}
