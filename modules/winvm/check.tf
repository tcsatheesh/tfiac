# Cross-field invariants surfaced at plan time.

resource "terraform_data" "assertions" {
  triggers_replace = {
    vm_name_hash  = sha1(local.vm_canonical_name)
    rg_name_hash  = sha1(local.rg_canonical_name)
    nic_name_hash = sha1(local.nic_name)
  }

  lifecycle {
    # WIN-INV-8: engine must have emitted the VM canonical name.
    precondition {
      condition     = contains(keys(module.naming.names), local.vm_canonical_name)
      error_message = "WIN-INV-8: naming engine did not emit VM key \"${local.vm_canonical_name}\". Engine keys: ${jsonencode(sort(keys(module.naming.names)))}."
    }

    # WIN-INV-8 twin: engine must have emitted the RG canonical name.
    precondition {
      condition     = contains(keys(module.naming.names), local.rg_canonical_name)
      error_message = "WIN-INV-8: naming engine did not emit RG key \"${local.rg_canonical_name}\". Engine keys: ${jsonencode(sort(keys(module.naming.names)))}."
    }

    # WIN-INV-9: derived NIC / disk / diagnostic / secret names fit Azure max.
    precondition {
      condition = alltrue([
        length(local.nic_name) <= 80,
        length(local.os_disk_name) <= 80,
        length(local.diag_vm_name) <= 260,
        length(local.diag_nic_name) <= 260,
        length(local.admin_password_secret_name) <= 127,
        length(local.computer_name) <= 15,
      ])
      error_message = format(
        "WIN-INV-9: at least one derived name exceeds Azure max. Lengths: nic=%d (max 80), osdisk=%d (max 80), diag_vm=%d (max 260), diag_nic=%d (max 260), secret=%d (max 127), computer=%d (max 15).",
        length(local.nic_name),
        length(local.os_disk_name),
        length(local.diag_vm_name),
        length(local.diag_nic_name),
        length(local.admin_password_secret_name),
        length(local.computer_name),
      )
    }
  }
}
