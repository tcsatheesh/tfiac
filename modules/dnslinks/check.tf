# Defence-in-depth alongside the hard-coded `registration_enabled = false`
# literal in main.tf (FR-212, C16.2, plan §9). If a future refactor ever
# turns the literal into a variable or a typo flips it to `true`, this
# check fires post-plan instead of silently shipping a foot-gun.

check "registration_disabled" {
  assert {
    condition = alltrue([
      for l in azurerm_private_dns_zone_virtual_network_link.this :
      l.registration_enabled == false
    ])
    error_message = "FR-212 / C16.2: at least one vnet-link has registration_enabled != false. Auto-registration on a privatelink.* zone is forbidden — see modules/dnslinks/README.md."
  }
}
