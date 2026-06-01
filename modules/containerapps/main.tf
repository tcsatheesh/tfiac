# C-021 (Amendment 2026-06-01) — Azure Container Apps internal Managed
# Environment (FR-030).
#
# Azure Container Apps has NO Azure Private Link / private-endpoint support, so
# its private form is an INTERNAL, VNet-injected environment:
#   * infrastructure_subnet_id is a spoke subnet delegated to
#     Microsoft.App/environments,
#   * internal_load_balancer_enabled = true removes the public ingress IP (the
#     environment is reachable only from the VNet),
#   * log_analytics_workspace_id is the shared hub LA (C-014).
# This internal environment is the documented exception to the private-by-default
# "private endpoint" requirement (CLAUDE.md mandate); the private default-domain
# DNS zone below provides the matching private-name-resolution.
resource "azurerm_container_app_environment" "this" {
  name                           = var.canonical_name
  resource_group_name            = var.resource_group_name
  location                       = var.location
  tags                           = var.tags
  log_analytics_workspace_id     = var.shared_log_analytics_workspace_id
  infrastructure_subnet_id       = var.infrastructure_subnet_id
  internal_load_balancer_enabled = true

  workload_profile {
    name                  = local.config.workload_profile_name
    workload_profile_type = local.config.workload_profile_type
  }
}

# Private DNS for the environment's default domain. Because the environment is
# internal, its default_domain resolves to the internal static IP only from
# inside a VNet that has the matching private DNS zone. We create that zone
# (named after the runtime default_domain), point a wildcard A-record at the
# environment static IP, and link the zone to the spoke VNet so all apps in the
# environment are reachable privately from the VNet.
resource "azurerm_private_dns_zone" "default_domain" {
  name                = azurerm_container_app_environment.this.default_domain
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_a_record" "wildcard" {
  name                = "*"
  zone_name           = azurerm_private_dns_zone.default_domain.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [azurerm_container_app_environment.this.static_ip_address]
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "spoke" {
  name                  = "${var.canonical_name}-vnl"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.default_domain.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}
