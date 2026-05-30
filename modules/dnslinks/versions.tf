# Terraform core version pin. Provider pins (including the
# `configuration_aliases = [azurerm.dns]` declaration) live in
# providers.tf to keep the provider-aliasing contract in one place.

terraform {
  required_version = "~> 1.9"
}
