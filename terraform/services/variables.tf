variable "market" {
  type = string
}
variable "environment" {
  type = string
}
variable "env_type" {
  type = string
  validation {
    condition     = var.env_type == "prd" || var.env_type == "pre" || var.env_type == "dev"
    error_message = "env_type must be either prd or pre or dev"
  }
}