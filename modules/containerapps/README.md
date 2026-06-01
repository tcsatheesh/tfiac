# modules/containerapps

Wrapper module for an **internal (private) Azure Container Apps Managed
Environment** (feature 006, amendment C-021 / FR-030).

Azure Container Apps has **no** Azure Private Link / private-endpoint
support. The private form delivered here is an internal, VNet-injected
Managed Environment plus a private DNS zone for its default domain:

| Resource | Purpose |
|----------|---------|
| `azurerm_container_app_environment.this` | Internal env: VNet-injected into a delegated spoke subnet, `internal_load_balancer_enabled = true` (no public ingress IP), linked to the shared hub Log Analytics workspace, one `Consumption` workload profile. |
| `azurerm_private_dns_zone.default_domain` | Private DNS zone named after the environment's runtime `default_domain`. |
| `azurerm_private_dns_a_record.wildcard` | Wildcard `*` A-record → environment internal static IP. |
| `azurerm_private_dns_zone_virtual_network_link.spoke` | Links the zone to the spoke VNet so apps resolve privately. |

This internal environment + private default-domain zone is the
documented exception to the project private-by-default "private
endpoint" mandate (see `CLAUDE.md`), because the service type cannot take
a private endpoint.

## Inputs

| Name | Description |
|------|-------------|
| `canonical_name` | Engine-emitted `cae-...` name. |
| `resource_group_name` | Services-stack RG. |
| `location` | Azure region. |
| `tags` | Engine-emitted tags. |
| `engine_record` | Full engine record. |
| `overrides` | Optional workload-profile overrides. |
| `shared_log_analytics_workspace_id` | Hub LA workspace ID (C-014). |
| `infrastructure_subnet_id` | Delegated (`Microsoft.App/environments`) spoke subnet. |
| `vnet_id` | Spoke VNet ID for the DNS link. |
