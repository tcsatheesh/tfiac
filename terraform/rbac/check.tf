# VC-33 — enabling the account user-owned-storage grant requires that the
# account/user-owned storage is actually resolvable from the services state and
# that both storage purposes are set and distinct.
check "aifoundry_user_owned_storage_rbac_prereqs" {
  assert {
    condition = !var.enable_aifoundry_user_owned_storage || (
      var.account_storage_purpose != null &&
      var.agent_storage_purpose != null &&
      var.account_storage_purpose != var.agent_storage_purpose &&
      local.account_storage_present &&
      local.agent_storage_present
    )
    error_message = "enable_aifoundry_user_owned_storage requires distinct agent_storage_purpose and account_storage_purpose that both resolve to storage accounts in the consumed services state (FR-049 / C-063)."
  }
}

# VC-34 — enabling the account Key Vault grants requires a key vault in the
# consumed services state.
check "aifoundry_keyvault_connection_rbac_prereqs" {
  assert {
    condition     = !var.enable_aifoundry_keyvault_connection || local.keyvault_present
    error_message = "enable_aifoundry_keyvault_connection requires a keyvault in the consumed services state (FR-046 / FR-047)."
  }
}
