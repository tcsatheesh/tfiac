# modules/dnszones/locals.tf
# Day-one catalogue (FR-011) — 25 entries, key → FQDN.
# Editing this map is a one-PR change (Constitution V / FR-013).
# Values stay INTERNAL per contracts/output-schema.md; only sorted keys are
# exposed via the `catalogue_keys` output.

locals {
  catalogue = {
    "blob"       = "privatelink.blob.core.windows.net"
    "file"       = "privatelink.file.core.windows.net"
    "queue"      = "privatelink.queue.core.windows.net"
    "table"      = "privatelink.table.core.windows.net"
    "dfs"        = "privatelink.dfs.core.windows.net"
    "web"        = "privatelink.web.core.windows.net"
    "vault"      = "privatelink.vaultcore.azure.net"
    "acr"        = "privatelink.azurecr.io"
    "openai"     = "privatelink.openai.azure.com"
    "cogsvc"     = "privatelink.cognitiveservices.azure.com"
    "search"     = "privatelink.search.windows.net"
    "cosmos-sql" = "privatelink.documents.azure.com"
    "webapp"     = "privatelink.azurewebsites.net"
    "automation" = "privatelink.azure-automation.net"
    "monitor"    = "privatelink.monitor.azure.com"
    "oms"        = "privatelink.oms.opinsights.azure.com"
    "ods"        = "privatelink.ods.opinsights.azure.com"
    "agentsvc"   = "privatelink.agentsvc.azure-automation.net"
    "aml-api"    = "privatelink.api.azureml.ms"
    "notebooks"  = "privatelink.notebooks.azure.net"
    "appconfig"  = "privatelink.azconfig.io"
    "servicebus" = "privatelink.servicebus.windows.net"
    "eventgrid"  = "privatelink.eventgrid.azure.net"
    "iothub"     = "privatelink.azure-devices.net"
    "iothub-dps" = "privatelink.azure-devices-provisioning.net"
  }
}
