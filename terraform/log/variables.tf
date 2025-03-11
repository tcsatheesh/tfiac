variable "market" {
  type = string
}
variable "environment" {
  type = string
}
variable "env_type" {
  type    = string
  default = "npd"
  validation {
    condition     = var.environment == "prd" || var.environment == "npd"
    error_message = "environment must be either prd or npd"
  }
}