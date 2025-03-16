variable "firewall_policy_id" {
  description = "The ID of the Firewall Policy to which this rule collection group belongs."
  type        = string
}
variable "source_ip_groups" {}


resource "azurerm_firewall_policy_rule_collection_group" "this" {
  name               = "AzureBuildServerCollectionGroup"
  firewall_policy_id = var.firewall_policy_id
  priority           = 300
  network_rule_collection {
    name     = "allow-buildserver-azureactivedirectory"
    priority = 1000
    action   = "Allow"
    rule {
      name                  = "azureactivedirectory"
      protocols             = ["TCP"]
      source_ip_groups      = var.source_ip_groups
      destination_addresses = ["AzureActiveDirectory"]
      destination_ports     = ["80", "443"]
    }
    rule {
      name                  = "azureactivedirectory-serviceendpoint"
      protocols             = ["TCP"]
      source_ip_groups      = var.source_ip_groups
      destination_addresses = ["AzureActiveDirectory.ServiceEndpoint"]
      destination_ports     = ["443"]
    }
  }
  network_rule_collection {
    name     = "allow-buildserver-azuremonitoring"
    priority = 1001
    action   = "Allow"
    rule {
      name                  = "azuremonitor"
      protocols             = ["TCP"]
      source_ip_groups      = var.source_ip_groups
      destination_addresses = ["ActionGroup", "ApplicationInsightsAvailability", "AzureMonitor"]
      destination_ports     = ["443"]
    }
  }
  network_rule_collection {
    name     = "allow-buildserver-azureresourcemanager"
    priority = 1002
    action   = "Allow"
    rule {
      name                  = "azure-resource-manager"
      protocols             = ["TCP"]
      source_ip_groups      = var.source_ip_groups
      destination_addresses = ["AzureResourceManager"]
      destination_ports     = ["443"]
    }
  }
  network_rule_collection {
    name     = "allow-buildserver-microsoftcontainerregistry"
    priority = 1003
    action   = "Allow"
    rule {
      name                  = "microsoft-container-registry"
      protocols             = ["TCP"]
      source_ip_groups      = var.source_ip_groups
      destination_addresses = ["MicrosoftContainerRegistry"]
      destination_ports     = ["443"]
    }
  }
  network_rule_collection {
    # https://learn.microsoft.com/en-us/azure/devops/organizations/security/allow-list-ip-url?view=azure-devops&tabs=IP-V4#outbound-connections
    name     = "allow-buildserver-azuredevops-ipaddresses"
    priority = 1004
    action   = "Allow"
    rule {
      name             = "azuredevopsipaddresses"
      protocols        = ["TCP"]
      source_ip_groups = var.source_ip_groups
      destination_addresses = ["13.107.6.0/24",
        "13.107.9.0/24",
        "13.107.42.0/24",
        "13.107.43.0/24"
      ]
      destination_ports = ["443"]
    }
  }
  network_rule_collection {
    # https://learn.microsoft.com/en-us/azure/devops/organizations/security/allow-list-ip-url?view=azure-devops&tabs=IP-V4#other-ip-addresses
    name     = "allow-buildserver-microsoft365commonandofficeips"
    priority = 1005
    action   = "Allow"
    rule {
      name             = "azuredevopsipaddresses"
      protocols        = ["TCP"]
      source_ip_groups = var.source_ip_groups
      destination_addresses = ["13.107.6.0/24",
        "13.107.9.0/24",
        "13.107.42.0/24",
        "13.107.43.0/24"
      ]
      destination_ports = ["80", "443"]
    }
  }
  application_rule_collection {
    # https://learn.microsoft.com/en-us/azure/devops/organizations/security/allow-list-ip-url?view=azure-devops&tabs=IP-V4#allowed-domain-urls
    name     = "allow-buildserver-azuredevops"
    priority = 1020
    action   = "Allow"
    rule {
      name             = "azuredevops"
      source_ip_groups = var.source_ip_groups
      protocols {
        port = "443"
        type = "Https"
      }
      destination_fqdns = [
        "dev.azure.com",
        "*.dev.azure.com",
        "aex.dev.azure.com",
        "aexprodea1.vsaex.visualstudio.com",
        "*vstmrblob.vsassets.io",
        "amp.azure.net",
        "app.vssps.dev.azure.com",
        "app.vssps.visualstudio.com",
        "*.vsblob.visualstudio.com",
        "*.vssps.visualstudio.com",
        "*.vstmr.visualstudio.com",
        "azure.microsoft.com",
        "go.microsoft.com",
        "graph.microsoft.com",
        "login.microsoftonline.com",
        "management.azure.com",
        "management.core.windows.net",
        "microsoft.com",
        "microsoftonline.com",
        "static2.sharepointonline.com",
        "visualstudio.com",
        "vsrm.dev.azure.com",
        "vstsagentpackage.azureedge.net",
        "*.windows.net",
        "cdn.vsassets.io",
        "*.vsassets.io",
        "*gallerycdn.vsassets.io",
        "aadcdn.msauth.net",
        "aadcdn.msftauth.net",
        "amcdn.msftauth.net",
        "azurecomcdn.azureedge.net",
      ]
    }
  }
  application_rule_collection {
    name     = "allow-buildserver-github"
    priority = 1021
    action   = "Allow"
    rule {
      name             = "github"
      source_ip_groups = var.source_ip_groups
      protocols {
        port = "443"
        type = "Https"
      }
      destination_fqdns = [
        "github.com",
        "api.github.com",
        "copilot-telemetry.githubusercontent.com",
        "default.exp-tas.com",
        "copilot-proxy.githubusercontent.com",
        "origin-tracker.githubusercontent.com",
        "*.githubcopilot.com",
        "raw.githubusercontent.com",
        "objects.githubusercontent.com",
      ]
    }
  }
  application_rule_collection {
    name     = "allow-buildserver-vodafone-github"
    priority = 1022
    action   = "Allow"
    rule {
      name             = "vodafone-github"
      source_ip_groups = var.source_ip_groups
      protocols {
        port = "443"
        type = "Https"
      }
      destination_fqdns = [
        "github.vodafone.com",
      ]
    }
  }
  application_rule_collection {
    name     = "allow-buildserver-python-packages"
    priority = 1023
    action   = "Allow"
    rule {
      name             = "pythonpackages"
      source_ip_groups = var.source_ip_groups
      protocols {
        port = "443"
        type = "Https"
      }
      destination_fqdns = [
        "pypi.org",
        "pypi.python.org",
        "pythonhosted.org",
        "files.pythonhosted.org",
      ]
    }
  }
  application_rule_collection {
    name     = "allow-buildserver-conda-packages"
    priority = 1024
    action   = "Allow"
    rule {
      name             = "condapackages"
      source_ip_groups = var.source_ip_groups
      protocols {
        port = "443"
        type = "Https"
      }
      destination_fqdns = [
        "repo.anaconda.com",
        "www.conda.io",
        "anaconda.org",
        "anaconda.com",
        "conda.anaconda.org",
      ]
    }
  }
  application_rule_collection {
    name     = "allow-buildserver-microsoft-packages"
    priority = 1025
    action   = "Allow"
    rule {
      name             = "microsoftpackages"
      source_ip_groups = var.source_ip_groups
      protocols {
        port = "443"
        type = "Https"
      }
      destination_fqdns = [
        "packages.microsoft.com",
      ]
    }
  }
  application_rule_collection {
    name     = "allow-buildserver-ubuntu-packages"
    priority = 1026
    action   = "Allow"
    rule {
      name             = "ubuntupackages"
      source_ip_groups = var.source_ip_groups
      protocols {
        port = "443"
        type = "Https"
      }
      protocols {
        port = "80"
        type = "Http"
      }
      destination_fqdns = [
        "azure.archive.ubuntu.com",
        "deb.debian.org",
        "security.debian.org",
      ]
    }
  }
  application_rule_collection {
    # https://learn.microsoft.com/en-us/powershell/gallery/getting-started?view=powershellget-3.x#network-access-to-the-powershell-gallery
    name     = "allow-buildserver-powershell-gallery"
    priority = 1027
    action   = "Allow"
    rule {
      name             = "powershellgallery"
      source_ip_groups = var.source_ip_groups
      protocols {
        port = "443"
        type = "Https"
      }
      destination_fqdns = [
        "www.powershellgallery.com",
        "onegetcdn.azureedge.net",
        "powershellgallery.azureedge.net",
        "*.powershellgallery.com",
        "go.microsoft.com",
      ]
    }
  }
  application_rule_collection {
    name     = "allow-buildserver-nuget"
    priority = 1028
    action   = "Allow"
    rule {
      name             = "nuget"
      source_ip_groups = var.source_ip_groups
      protocols {
        port = "443"
        type = "Https"
      }
      destination_fqdns = [
        "azurewebsites.net",
        "*.nuget.org",
      ]
    }
  }
  application_rule_collection {
    name     = "allow-buildserver-visualstudio-download"
    priority = 1029
    action   = "Allow"
    rule {
      name             = "visualstudiodownload"
      source_ip_groups = var.source_ip_groups
      protocols {
        port = "443"
        type = "Https"
      }
      destination_fqdns = [
        "download.visualstudio.microsoft.com",
        "dotnetcli.azureedge.net",     # fallback url for download
        "builds.dotnet.microsoft.com", # for dotnet sdk
      ]
    }
  }
  application_rule_collection {
    # https://github.com/microsoft/containerregistry/blob/main/docs/client-firewall-rules.md
    name     = "allow-buildserver-microsoft-artifact-registry"
    priority = 1030
    action   = "Allow"
    rule {
      name             = "microsoftartifactregistry"
      source_ip_groups = var.source_ip_groups
      protocols {
        port = "443"
        type = "Https"
      }
      destination_fqdns = [
        "mcr.microsoft.com",
        "*.data.mcr.microsoft.com",
      ]
    }
  }
  application_rule_collection {
    name     = "allow-buildserver-azure-cli"
    priority = 1031
    action   = "Allow"
    rule {
      name             = "azurecli"
      source_ip_groups = var.source_ip_groups
      protocols {
        port = "443"
        type = "Https"
      }
      destination_fqdns = [
        "aka.ms" // enable cli extension installation
      ]
    }
  }
  application_rule_collection {
    name     = "allow-buildserver-vm-guest-configuration"
    priority = 1032
    action   = "Allow"
    rule {
      name             = "azurevmguestconfiguration"
      source_ip_groups = var.source_ip_groups
      protocols {
        port = "443"
        type = "Https"
      }
      destination_fqdns = [
        "westeurope-gas.guestconfiguration.azure.com" // https://learn.microsoft.com/en-us/azure/virtual-machines/extensions/guest-configuration
      ]
    }
  }
  application_rule_collection {
    name     = "allow-mend-installer"
    priority = 1033
    action   = "Allow"
    rule {
      name             = "mendconfiguration"
      source_ip_groups = var.source_ip_groups
      protocols {
        port = "443"
        type = "Https"
      }
      destination_fqdns = [
        "downloads.mend.io"
      ]
    }
  }
}