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
    condition     = var.env_type == "prd" || var.env_type == "npd"
    error_message = "env_type must be either prd or npd"
  }
}