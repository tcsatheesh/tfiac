# terraform/vnet/dns.tf
#
# Cross-stack DNS wiring: reads the DNS stack's `zone_ids` output via
# remote-state and links every zone to this stack's vnet. Held in a
# dedicated file (rather than appended to main.tf) to keep the
# DNS-cross-stack concern visually isolated per plan §5 — mirrors the
# per-concern split already used by backend.tf / providers.tf /
# locals.tf.
#
# FR-211, FR-215, FR-219, C16.1, C16.5, C16.9.

# Unconditional remote-state lookup — both hub and spoke roles need
# links per C16.1, so NO `count` guard (contrast the spoke-only
# data.terraform_remote_state.hub block in main.tf which IS count=0
# for hub).
data "terraform_remote_state" "dns" {
  backend = "azurerm"

  config = {
    subscription_id      = var.dns_state_backend.subscription_id
    resource_group_name  = var.dns_state_backend.resource_group_name
    storage_account_name = var.dns_state_backend.storage_account_name
    container_name       = var.dns_state_backend.container_name
    key                  = var.dns_state_backend.key
    use_azuread_auth     = true
  }
}

module "dnslinks" {
  source = "../../modules/dnslinks"

  providers = {
    azurerm.dns = azurerm.dns
  }

  vnet_id   = module.network.vnet_id
  vnet_name = module.network.vnet_name
  zone_ids  = data.terraform_remote_state.dns.outputs.zone_ids
  tags      = module.network.vnet_tags

  dns_subscription_id = var.dns_state_backend.subscription_id
}
