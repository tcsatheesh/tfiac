# Wrapper invariants (defence-in-depth alongside root stack check.tf).
# VNET-INV-5, -8, -10 are wrapper-scoped; the rest live at the root.

resource "terraform_data" "assertions" {
  triggers_replace = {
    role              = var.role
    subnet_roles_sha  = sha1(join(",", local.active_roles))
    naming_keys_sha   = sha1(join(",", sort(keys(module.naming.names))))
    address_space_sha = sha1(join(",", var.address_space))
  }

  # VNET-INV-5: every subnet role must exist in the local role catalogue.
  lifecycle {
    precondition {
      condition = alltrue([
        for r in local.active_roles : contains(keys(local.role_catalogue), r)
      ])
      error_message = format(
        "VNET-INV-5: unknown subnet role(s): %s. Allowed: %s.",
        jsonencode([for r in local.active_roles : r if !contains(keys(local.role_catalogue), r)]),
        jsonencode(sort(keys(local.role_catalogue))),
      )
    }

    # VNET-INV-10: hub deployments require bastion + firewall + firewall-mgmt subnets.
    precondition {
      condition = (
        var.role != "hub"
        || (
          contains(local.active_roles, "bastion")
          && contains(local.active_roles, "firewall")
          && contains(local.active_roles, "firewall-mgmt")
        )
      )
      error_message = "VNET-INV-10: hub role requires subnet roles \"bastion\", \"firewall\", and \"firewall-mgmt\" in var.subnets."
    }

    # VNET-INV-8 (snapshot): naming engine must emit the locally-computed canonical names.
    precondition {
      condition = (
        contains(keys(module.naming.names), local.vnet_canonical_name)
        && contains(keys(module.naming.names), local.rg_canonical_name)
        && contains(keys(module.naming.names), local.rt_canonical_name)
        && alltrue([for n in values(local.nsg_canonical_names) : contains(keys(module.naming.names), n)])
      )
      error_message = format(
        "VNET-INV-8: engine did not emit one or more expected canonical names. Expected to find %s in keys(module.naming.names) = %s.",
        jsonencode(concat([local.vnet_canonical_name, local.rg_canonical_name, local.rt_canonical_name], values(local.nsg_canonical_names))),
        jsonencode(sort(keys(module.naming.names))),
      )
    }

    # Spoke role hard requirement: hub_vnet_id + hub_firewall_private_ip must be supplied.
    precondition {
      condition = (
        var.role != "spoke"
        || (var.hub_vnet_id != null && var.hub_firewall_private_ip != null)
      )
      error_message = "VNET-INV-spoke: spoke role requires hub_vnet_id and hub_firewall_private_ip to be supplied by the root stack."
    }
  }
}
