# Feature 000-bootstrap - pinned to repo-wide provider versions.
# The bootstrap stack is intentionally small so it pulls only the
# providers it strictly needs (azurerm + azapi for AVM transitive),
# matching the lockfile inherited from terraform/vnet/.
terraform {
  required_version = "~> 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}
