variable "dns" {}
variable "log" {}
variable "vnet" {}
variable "services" {}

variable "storage_account_id" {
  description = "The ID of the storage account."
  type        = string
}

variable "open_ai_id" {
  description = "The ID of the OpenAI resource."
  type        = string
}