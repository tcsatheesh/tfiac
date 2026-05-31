# Day-one catalogue: Microsoft-published private-link DNS zones for the Azure
# global cloud. Mirrors spec.md FR-011 verbatim (26 entries). Adding a row here
# MUST be accompanied by the same edit in spec.md FR-011 (enforced by
# tests/catalogue_completeness.tftest.hcl and the SC-008 grep audit).
#
# Constitution / spec contract:
#   FR-012 - catalogue keys are unique, lowercase alphanum + hyphen, length 2..16.
#   FR-013 - catalogue lives in the stack's module, NOT in modules/naming.
#   FR-008 - zone Azure name = the FQDN literally.

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
    "aiservices" = "privatelink.services.ai.azure.com"
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
