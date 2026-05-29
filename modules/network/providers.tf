terraform {
  required_version = "~> 1.9"

  # Module-level required_providers — passthrough only. Provider
  # configuration is supplied by the consuming root stack
  # (Constitution VI). The wrapper itself does NOT need a hub-aliased
  # provider; only the peering submodule does (root stack instantiates
  # that separately).
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.4"
    }
    modtm = {
      source  = "azure/modtm"
      version = "~> 0.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
  }
}
