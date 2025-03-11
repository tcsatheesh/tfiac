variable "market" {
  type = string
}
variable "environment" {
  type = string
}
variable "env_type" {
  type    = string
  validation {
    condition     = var.env_type == "prd"
    error_message = "env_type must be either prd or pre or dev"
  }
}